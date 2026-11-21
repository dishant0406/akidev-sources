//! Template: an indexer whose answer is an HTML page.
//!
//! The app calls `search` with {host, kind, path, query, json} (the filled request, as hints). This module
//! asks the host to fetch the page (`http`), reads rows out of the HTML, and answers with
//! {"items": [{title, hash, size, seeders}]}. The plugin's own `response` then reads that JSON, so the
//! app's normal checks (a valid hash, the right episode, ranking) still apply to every row.
//!
//! What to change, marked TODO below: the page address, how a row starts and ends, and where each value is.
//! Only serde_json is used. Parsing is plain string scanning, which keeps the module small (the limit is 4 MB).

use serde_json::{json, Value};

#[link(wasm_import_module = "akidev")]
extern "C" {
    fn http(pointer: i32, length: i32) -> i64;
}

// ---- plumbing: you should not need to change anything in this block -----------------------------

/// The host calls this to put the input into this module's memory.
#[no_mangle]
pub extern "C" fn alloc(length: i32) -> i32 {
    let mut space = Vec::<u8>::with_capacity(length as usize);
    let pointer = space.as_mut_ptr();
    std::mem::forget(space);
    pointer as i32
}

/// Hands JSON back: where it is, and how many bytes.
fn give(value: &Value) -> i64 {
    let bytes = serde_json::to_vec(value).unwrap();
    let length = bytes.len();
    let pointer = bytes.leak().as_ptr();
    (((pointer as u32 as u64) << 32) | length as u64) as i64
}

fn take(pointer: i32, length: i32) -> Vec<u8> {
    unsafe { std::slice::from_raw_parts(pointer as *const u8, length as usize).to_vec() }
}

/// One request through the host. The answer is {status, body}, or {error} when it is refused or fails.
fn fetch(request: Value) -> Value {
    let bytes = serde_json::to_vec(&request).unwrap();
    let packed = unsafe { http(bytes.as_ptr() as i32, bytes.len() as i32) } as u64;
    let answer = take((packed >> 32) as i32, (packed & 0xffff_ffff) as i32);
    serde_json::from_slice(&answer).unwrap_or(Value::Null)
}

// ---- small helpers for reading HTML -------------------------------------------------------------

/// The text between `start` and `end`, searching from the beginning of `text`.
/// Returns it and the position just after `end`.
fn between<'a>(text: &'a str, start: &str, end: &str) -> Option<(&'a str, usize)> {
    let from = text.find(start)? + start.len();
    let length = text[from..].find(end)?;
    Some((&text[from..from + length], from + length + end.len()))
}

/// Removes tags and turns the few common entities into text.
fn plain(html: &str) -> String {
    let mut out = String::new();
    let mut inside = false;
    for character in html.chars() {
        match character {
            '<' => inside = true,
            '>' => inside = false,
            other if !inside => out.push(other),
            _ => {}
        }
    }
    out.replace("&amp;", "&")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .trim()
        .to_string()
}

/// The 40 hex digits after "btih:" in a magnet link, in lower case.
fn info_hash(magnet: &str) -> Option<String> {
    let at = magnet.find("btih:")? + 5;
    let hash: String = magnet[at..].chars().take_while(|c| c.is_ascii_alphanumeric()).collect();
    (hash.len() == 40 || hash.len() == 32).then(|| hash.to_ascii_lowercase())
}

/// Text safe to put in an address.
fn encode(text: &str) -> String {
    text.bytes()
        .map(|byte| match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => (byte as char).to_string(),
            other => format!("%{other:02X}"),
        })
        .collect()
}

// ---- the part you write -------------------------------------------------------------------------

#[no_mangle]
pub extern "C" fn search(pointer: i32, length: i32) -> i64 {
    let input: Value = serde_json::from_slice(&take(pointer, length)).unwrap_or(Value::Null);
    let host = input["host"].as_str().unwrap_or_default();
    // The search term is in the query the app filled from the plugin's request ("q": "{term}").
    let term = input["query"]
        .as_array()
        .and_then(|pairs| pairs.iter().find(|pair| pair[0] == "q"))
        .and_then(|pair| pair[1].as_str())
        .unwrap_or_default();

    // TODO 1: the address of the search page. Use the same host the plugin declares.
    let answer = fetch(json!({
        "url": format!("{host}/search?q={}", encode(term)),
        // TODO: add headers the site wants (a user agent, a cookie the user supplies, a signature).
        "headers": {},
    }));
    let page = answer["body"].as_str().unwrap_or_default();

    let mut rows = Vec::new();
    let mut rest = page;
    // TODO 2: what starts and ends one result row in the HTML. Look at the page source.
    while let Some((row, used)) = between(rest, "<tr class=\"result\">", "</tr>") {
        rest = &rest[used..];

        // TODO 3: where each value is inside the row.
        let magnet = between(row, "href=\"magnet:", "\"")
            .map(|(link, _)| format!("magnet:{link}"))
            .unwrap_or_default();
        let Some(hash) = info_hash(&magnet) else { continue };
        let title = between(row, "<a class=\"title\"", "</a>")
            .map(|(cell, _)| plain(cell.split_once('>').map(|(_, text)| text).unwrap_or(cell)))
            .unwrap_or_default();
        let size = between(row, "<td class=\"size\">", "</td>").map(|(cell, _)| plain(cell));
        let seeders = between(row, "<td class=\"seeds\">", "</td>")
            .and_then(|(cell, _)| plain(cell).parse::<u64>().ok());

        if !title.is_empty() {
            rows.push(json!({ "title": title, "hash": hash, "size": size, "seeders": seeders }));
        }
    }
    give(&json!({ "items": rows }))
}

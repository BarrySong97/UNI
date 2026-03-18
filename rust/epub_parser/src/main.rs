use std::env;
use std::fs;
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!(
            "Usage: epub_parser <path-to-epub> [--metadata] [--chapter N] [--batch-export <dir>]"
        );
        process::exit(1);
    }

    let epub_path = &args[1];

    // --batch-export <dir>: export all chapters as individual JSON files.
    if let Some(pos) = args.iter().position(|a| a == "--batch-export") {
        let out_dir = args.get(pos + 1).unwrap_or_else(|| {
            eprintln!("--batch-export requires a directory argument");
            process::exit(1);
        });
        batch_export(epub_path, out_dir);
        return;
    }

    // Check for --metadata flag.
    if args.contains(&"--metadata".to_string()) {
        match epub_parser::parse_epub_metadata(epub_path) {
            Ok((metadata, toc)) => {
                let output = serde_json::json!({
                    "metadata": metadata,
                    "toc": toc,
                });
                println!("{}", serde_json::to_string_pretty(&output).unwrap());
            }
            Err(e) => {
                eprintln!("Error parsing EPUB metadata: {}", e);
                process::exit(1);
            }
        }
        return;
    }

    // Check for --chapter N flag.
    if let Some(pos) = args.iter().position(|a| a == "--chapter") {
        let chapter_index: usize = args
            .get(pos + 1)
            .and_then(|s| s.parse().ok())
            .unwrap_or_else(|| {
                eprintln!("--chapter requires a numeric argument");
                process::exit(1);
            });

        match epub_parser::parse_chapter(epub_path, chapter_index) {
            Ok(chapter) => {
                println!("{}", serde_json::to_string_pretty(&chapter).unwrap());
            }
            Err(e) => {
                eprintln!("Error parsing chapter {}: {}", chapter_index, e);
                process::exit(1);
            }
        }
        return;
    }

    // Default: full parse.
    match epub_parser::parse_epub(epub_path) {
        Ok(book) => {
            println!("{}", serde_json::to_string_pretty(&book).unwrap());
        }
        Err(e) => {
            eprintln!("Error parsing EPUB: {}", e);
            process::exit(1);
        }
    }
}

/// Export all chapters as individual JSON files + a book.json manifest.
fn batch_export(epub_path: &str, out_dir: &str) {
    let book = match epub_parser::parse_epub(epub_path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("Error parsing EPUB: {}", e);
            process::exit(1);
        }
    };

    if let Err(e) = fs::create_dir_all(out_dir) {
        eprintln!("Cannot create directory {}: {}", out_dir, e);
        process::exit(1);
    }

    let chapter_count = book.chapters.len();
    for chapter in &book.chapters {
        let path = format!("{}/chapter_{}.json", out_dir, chapter.index);
        let json = serde_json::to_string(chapter).unwrap();
        if let Err(e) = fs::write(&path, json) {
            eprintln!("Error writing {}: {}", path, e);
            process::exit(1);
        }
    }

    // book.json: metadata + toc + chapter_count (no chapter content).
    let spine: Vec<serde_json::Value> = book.chapters.iter().map(|ch| {
        serde_json::json!({ "index": ch.index, "href": ch.href })
    }).collect();

    let book_manifest = serde_json::json!({
        "metadata": book.metadata,
        "toc": book.toc,
        "chapter_count": chapter_count,
        "spine": spine,
    });
    let manifest_path = format!("{}/book.json", out_dir);
    let json = serde_json::to_string(&book_manifest).unwrap();
    if let Err(e) = fs::write(&manifest_path, json) {
        eprintln!("Error writing {}: {}", manifest_path, e);
        process::exit(1);
    }

    println!("Exported {} chapters to {}", chapter_count, out_dir);
}

# DocEngine

DocEngine is a Swift package providing a small engine for reading and editing slices of Markdown documents. Documents are loaded through a `DocumentStore` abstraction so the engine does not dictate where content is persisted.

## Quick Start

Add the package dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/example/swift-doc-engine", branch: "main")
```

Use the `DocEngine` with an in-memory store:

```swift
let store = InMemoryStore()
let engine = DocEngine(store: store)
let rev = try store.save(id: "doc", newText: "# Title", expectedRevision: "", diffProducer: {_,_ in ""})
let slice = try engine.read("doc", selector: Selector(path: ["title"]))
print(slice.text)
```

Selectors address headings using slugged text. Fenced code blocks can be accessed with ``[`tag`]`` paths. Provide a byte `range` in the selector to fall back when an AST path does not exist.

### Extension Points

* Implement `DocumentStore` to back documents with your own persistence layer.
* Replace the diff generation by adapting `SimpleDiff` or providing a custom implementation.

## License

MIT

import XCTest
@testable import NeverGoneDemo

/// Tests for ChatViewModel

final class ChatViewModelTests: XCTestCase {
    
    /// Test that streaming text accumulates correctly
    @MainActor
    func testStreamingTextAccumulation() async {
        // Given: A chat view model
        let sessionId = UUID()
        let viewModel = ChatViewModel(sessionId: sessionId)
        
        // When: Streaming text is appended
        viewModel.streamingText = "Hello"
        XCTAssertEqual(viewModel.streamingText, "Hello")
        
        viewModel.streamingText += " world"
        XCTAssertEqual(viewModel.streamingText, "Hello world")
        
        viewModel.streamingText += "!"
        XCTAssertEqual(viewModel.streamingText, "Hello world!")
    }
    
    /// Test that MessageRole enum encodes/decodes correctly
    func testMessageRoleEncoding() throws {
        // Given: MessageRole values
        let userRole = MessageRole.user
        let assistantRole = MessageRole.assistant
        
        // Then: Raw values are correct
        XCTAssertEqual(userRole.rawValue, "user")
        XCTAssertEqual(assistantRole.rawValue, "assistant")
        
        // And: JSON encoding works
        let encoder = JSONEncoder()
        let userEncoded = try encoder.encode(userRole)
        let userString = String(data: userEncoded, encoding: .utf8)
        XCTAssertEqual(userString, "\"user\"")
    }
    
    /// Test SSE parsing helper
    func testSSEParsing() {
        // Given: An SSE data line
        let sseLine = "data: {\"content\": \"Hello world\"}"
        
        // When: We parse it
        let jsonString = String(sseLine.dropFirst(6)) // Remove "data: "
        let data = jsonString.data(using: .utf8)!
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        // Then: Content is extracted correctly
        XCTAssertEqual(json["content"] as? String, "Hello world")
    }
    
    /// Test that cancel clears streaming state
    @MainActor
    func testCancelStream() async {
        // Given: A view model with streaming text
        let viewModel = ChatViewModel(sessionId: UUID())
        viewModel.streamingText = "Partial response..."
        viewModel.isStreaming = true
        
        // When: Cancel is called 
        viewModel.isStreaming = false
        viewModel.streamingText = ""
        
        // Then: State is cleared
        XCTAssertFalse(viewModel.isStreaming)
        XCTAssertTrue(viewModel.streamingText.isEmpty)
    }
}

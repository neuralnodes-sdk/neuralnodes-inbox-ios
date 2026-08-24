import XCTest
@testable import NeuralNodesInbox

/// Decode round-trip tests against realistic backend JSON (field names
/// copied directly from migrations/table-schemas.txt's escalated_sessions
/// DDL and services/pusher_service.py's event payloads). This model
/// previously had no assignedTo/assignedToName/clientId/sessionId/
/// escalatedAt fields at all - the decoder had nowhere to put them, so
/// the SDK had no way to know who owned a chat.
final class EscalationDecodingTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testDecodesOwnershipFieldsFromRealisticBackendJSON() throws {
        let json = """
        {
            "id": "esc-1",
            "client_id": "client-1",
            "session_id": "sess-abc",
            "status": "active",
            "lead_name": "Jane Doe",
            "lead_email": "jane@example.com",
            "assigned_to": "agent-9",
            "assigned_to_name": "Jordan",
            "escalation_type": "chat",
            "priority": "normal",
            "unread_count": 2,
            "escalated_at": "2026-01-01T00:00:00Z",
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:05:00Z"
        }
        """.data(using: .utf8)!

        let escalation = try decoder.decode(Escalation.self, from: json)

        XCTAssertEqual(escalation.clientId, "client-1")
        XCTAssertEqual(escalation.sessionId, "sess-abc")
        XCTAssertEqual(escalation.assignedTo, "agent-9")
        XCTAssertEqual(escalation.assignedToName, "Jordan")
        XCTAssertTrue(escalation.isOwned)
    }

    func testUnownedEscalationHasNilAssignedToAndIsOwnedFalse() throws {
        let json = """
        {
            "id": "esc-2",
            "client_id": "client-1",
            "session_id": "sess-xyz",
            "status": "pending",
            "unread_count": 0,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let escalation = try decoder.decode(Escalation.self, from: json)

        XCTAssertNil(escalation.assignedTo)
        XCTAssertFalse(escalation.isOwned)
    }

    func testDecodesStatusChangedEventFromPusherServiceSendEscalationStatusChange() throws {
        let json = """{"status": "resolved", "assigned_to": "agent-9", "assigned_to_name": "Jordan", "timestamp": "2026-01-01T00:00:00Z"}""".data(using: .utf8)!

        let event = try decoder.decode(EscalationStatusChange.self, from: json)

        XCTAssertEqual(event.status, "resolved")
        XCTAssertEqual(event.assignedTo, "agent-9")
    }

    func testDecodesAgentJoinedEventFromPusherServiceSendAgentJoined() throws {
        let json = """{"agent_name": "Jordan", "agent_id": "agent-9", "timestamp": "2026-01-01T00:00:00Z"}""".data(using: .utf8)!

        let event = try decoder.decode(AgentJoinedEvent.self, from: json)

        XCTAssertEqual(event.agentName, "Jordan")
        XCTAssertEqual(event.agentId, "agent-9")
    }

    func testDecodesOwnershipChangedEventFromPusherServiceSendOwnershipEvent() throws {
        let json = """{"event": "taken_over", "escalation_id": "esc-1", "new_owner": "agent-2", "new_owner_name": "Sam", "previous_owner": "agent-9", "timestamp": "2026-01-01T00:00:00Z"}""".data(using: .utf8)!

        let event = try decoder.decode(OwnershipChangedEvent.self, from: json)

        XCTAssertEqual(event.event, "taken_over")
        XCTAssertEqual(event.newOwner, "agent-2")
        XCTAssertEqual(event.previousOwner, "agent-9")
    }

    func testTypingIndicatorRequestEncodesEscalationIdInTheBody() throws {
        let request = TypingIndicatorRequest(escalationId: "esc-1", senderName: "Jordan", isTyping: true)

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["escalation_id"] as? String, "esc-1")
        XCTAssertEqual(json["sender_type"] as? String, "agent")
        XCTAssertEqual(json["is_typing"] as? Bool, true)
    }
}

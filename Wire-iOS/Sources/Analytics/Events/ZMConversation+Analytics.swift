//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation

enum ConversationType: Int {
    case oneToOne
    case group
}

extension ConversationType {
    var analyticsTypeString : String {
        switch  self {
        case .oneToOne:     return "one_to_one"
        case .group:        return "group"
        }
    }
    
    static func type(_ conversation: ZMConversation) -> ConversationType? {
        switch conversation.conversationType {
        case .oneOnOne:
            return .oneToOne
        case .group:
            return .group
        default:
            return nil
        }
    }
}

extension ZMConversation {
    
    func analyticsTypeString() -> String? {
        return ConversationType.type(self)?.analyticsTypeString
    }
        
    ///TODO: move to DM
    /// Whether the conversation is a 1-on-1 conversation with a service user
    var isOneOnOneServiceUserConversation: Bool {
        guard self.localParticipants.count == 2,
             let otherUser = firstActiveParticipantOtherThanSelf else {
            return false
        }
        
        return otherUser.serviceIdentifier != nil &&
                otherUser.providerIdentifier != nil
    }
    
    ///TODO: move to DM
    /// Whether the conversation includes at least 1 service user.
    var includesServiceUser: Bool {
        let participants = Array(localParticipants)
        return participants.any { $0.isServiceUser }
    }
    
    static let userNameSorter: (UserType, UserType) -> Bool = { user0, user1 in
        user0.name < user1.name
    }
    
    ///TODO: move to DM
    var sortedServiceUsers: [UserType] {
        return localParticipants.filter { $0.isServiceUser }.sorted(by: ZMConversation.userNameSorter)
    }

    ///TODO: move to DM
    @objc
    var sortedOtherParticipants: [UserType] {
        return localParticipants.filter { !$0.isServiceUser }.sorted(by: ZMConversation.userNameSorter)
    }

}


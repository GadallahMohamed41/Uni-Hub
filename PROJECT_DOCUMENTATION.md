# NATU- Students- Technical Documentation

## 1. Current State Analysis

**Project Setup & Configuration**
`NATU-Students` is a Flutter application using a modular, feature-centric architecture. It is fully integrated with Firebase (Auth, Firestore, FCM, Storage) and Supabase.

**Key Libraries & Dependencies**
- **State Management:** Provider (`^6.1.2`)
- **Backend:** Firebase (Core `4.4.0`, Messaging `16.1.1`, Auth `6.1.4`), Supabase (`^2.5.6`)
- **Android Platform:** Requires **compileSdk 36** and **targetSdk 35**.
- **Local Data:** `shared_preferences`, Secure local chat storage logic.
## 2. Architecture Overview

**Pattern: Feature-First / Modular**
The app groups logic by feature (`auth`, `assistant`, `chat`, `community`, etc.) rather than technical layer. This ensures that UI, Providers, and domain models for a specific feature stay together.

**Advanced Notification Flow**:
1.  **In-App**: Uses a real-time Firestore snapshots listener for instant UI updates.
2.  **Background**: Uses a Cloud Functions (v2 API) trigger.
    - **Trigger**: `onDocumentCreated` (region: `europe-west1`).
    - **Mechanism**: Sends a "Data-Only" high-priority FCM payload.
    - **Background Handling**: `@pragma('vm:entry-point')` handler boots a background isolate. 
    - **Action Handlers**: Background actions (Like, Approve, Reject) require `DartPluginRegistrant.ensureInitialized()` and `onDidReceiveBackgroundNotificationResponse` for database interaction when the app is terminated.
    - **Dynamic Navigation**: Handled gracefully using a `GlobalKey<NavigatorState>` that waits for `flutter_local_notifications` launch details to execute before pushing explicit routes (like navigating to specific posts with the `Review` action).

**State Management (Real-Time Streams)**:
- Components like `NotificationsScreen` cache the `Stream<List<Map<String, dynamic>>>` at the `State` level (reacting accurately dynamically to `didChangeDependencies` when the authentication token changes). This ensures `StreamBuilder` references are not accidentally torn-down leading to dropped UI synchronizations.

---

## 3. Implementation Details

- **AI Assistant (`AiService`)**: Connects to an external LLM backend. Features a custom "Peek" slider UI and floating button interaction.
- **Theme Engine**: Dynamic dark/light mode toggling with persistence, globally managed via `ThemeProvider`.
- **Media Handling**: Support for video playback (`video_player`), image picking, and file uploads to Firebase Storage.

---

## 4. Maintenance & Deployment

### 🔴 Critical Requirements (Android)
- **Notification Icon**: A monochrome white icon at `android/app/src/main/res/drawable/ic_notification.xml` is mandatory for background notifications.
- **Isolate Handling**: Do not perform heavy networking or image downloads in the `firebaseMessagingBackgroundHandler` as Android "Doze" mode may kill the process.
- **Background Actions**: Actions must use a static top-level function. Firebase must be re-initialized within the background isolate if database operations (Firestore) are required.

### Deploying Cloud Functions
The notification logic relies on Node.js functions.
```bash
cd functions
firebase deploy --only functions
```
---

## 5. Roadmap (Phase 2 & Beyond)

- [ ] **Notification Audit**: (In Progress) Fixing background/killed state action failures (Likes/Reactions).
- [ ] **Offline-First Resilience**: Implement `Hive` for community feed caching.
- [ ] **Pagination**: Migration to cursor-based pagination for Firestore feeds to reduce read costs.
- [ ] **Consolidation**: Moving towards a unified backend (Firebase or Supabase) to reduce dependency footprint.

## 6. Profile Posts Feature (New Enhancement)

* Added user-specific posts display in profile screen
* Fetches posts based on `userId`
* Integrates with existing Firestore structure
* Displays posts under profile information section
* Supports real-time updates using Firestore snapshots
* Maintains UI consistency with community feed design
* Enhances user engagement and profile interaction
* Reduces navigation between screens
* Fully aligned with feature-first architecture
* Compatible with existing state management (Provider / Streams)

---

## 7. Threaded Comments & Reactions System

**Summary**
- `commentsCount` on posts counts all comments **and** replies (multi-level), excluding soft-deleted items.
- Each comment document can be a root comment (`parentCommentId == null`) or a nested reply.
- Comments are soft-deleted via `isDeleted = true`; streams filter them out so they never appear in UI.
- Deleting a post cascades to all reposts (`repostOf`) and their comments.
- Comment and reaction events (comment, reply, mention, comment_like) are fully integrated with the existing notifications collection.
- Home feed and post detail screens render a threaded UI with:
  - Indented replies,
  - “View more replies” for large threads,
  - Smooth scroll + highlight when tapping the comments counter,
  - Modern bottom-sheet UI for replying on both Home and Profile screens.

---

## 8. Connections & Follow System (LinkedIn-Style)

- **Firestore Schema**
  - `users/{uid}`
    - New counters: `followersCount`, `followingCount`, `connectionsCount` (int, default `0`).
  - `users/{uid}/followers/{followerUid}`
    - Fields: `userId`, `createdAt`.
  - `users/{uid}/following/{targetUid}`
    - Fields: `userId`, `createdAt`.
  - `users/{uid}/connections/{otherUid}`
    - Fields: `userId`, `createdAt`.
  - `users/{uid}/incomingConnectionRequests/{fromUid}`
    - Fields: `fromUserId`, `toUserId`, `createdAt`.
  - `users/{uid}/outgoingConnectionRequests/{toUid}`
    - Fields: `fromUserId`, `toUserId`, `createdAt`.
  - `notifications/{notificationId}` (existing collection)
    - Reused for:
      - `type: "connection_request"` (new connection request).
      - `type: "request_accepted"` (connection accepted).
    - Fields: `toUserId`, `fromUserId`, `createdAt`, `read`, plus existing optional metadata.

- **Domain / Data**
  - New repository: `ConnectionsRepository`  
    - Location: `lib/features/connections/data/connections_repository.dart`.
    - Responsibilities:
      - `sendConnectionRequest`, `acceptConnectionRequest`, `ignoreConnectionRequest`.
      - `followUser`, `unfollowUser`.
      - `watchConnections(userId)` → `Stream<List<UserModel>>`.
      - `watchIncomingRequests(userId)` → `Stream<List<UserModel>>`.
      - `fetchSuggestedUsers(userId, limit)` → `Future<List<UserModel>>`.
      - `getConnectionStatus(currentUserId, otherUserId)` → `ConnectionStatus` enum.
      - `isFollowing(currentUserId, otherUserId)` → `bool`.
  - The repository is built directly on top of `FirebaseFirestore` and reuses the central `users` collection and the global `notifications` collection used by FCM triggers.

- **Presentation**
  - BLoC: `ConnectionsBloc`
    - Location: `lib/features/connections/presentation/connections_bloc.dart`.
    - Manages:
      - Live connections list.
      - Live incoming connection requests.
      - Suggested users (people you may know).
      - Actions: send request, accept, ignore.
  - Screen: `ConnectionsScreen`
    - Location: `lib/features/connections/presentation/connections_screen.dart`.
    - Added to bottom navigation (see `lib/layout/main_layout.dart`):
      - Tabs: Home, Chats, Community, **Connections**, Profile.
    - Sections:
      - **Pending Requests**: list of incoming requests with `Accept` / `Ignore`.
      - **Connections**: all accepted connections with `Connected` state button.
      - **People you may know**: suggested users with `Connect` button.
      - **Search**: top search bar using `FirestoreService.searchUsers()` with per‑result `Connect` button.
  - Profile integration: `UserProfileScreen`
    - Location: `lib/features/profile/user_profile_screen.dart`.
    - New stats row under the name:
      - `Followers`, `Following`, `Connections` (bound to user counters).
    - New actions (for other users’ profiles):
      - Primary button: `Connect` / `Pending` / `Connected` / `Accept` (for incoming requests).
      - Secondary button: `Follow` / `Following` (toggle follow state).
    - Logic:
      - Uses `ConnectionsRepository` to:
        - Resolve `ConnectionStatus` between current user and profile user.
        - Resolve follow state (`isFollowing`).
        - Dispatch connect / accept / ignore / follow / unfollow actions.
      - After actions, user counters are refreshed by reloading the user document from Firestore.

---

## 9. Clean Architecture Notes (Social Layer)

- **Presentation Layer**
  - BLoC/Cubit used for the new Connections feature (`ConnectionsBloc`).
  - UI widgets kept dumb; all side-effects delegated to the BLoC and repository.
- **Domain / Data**
  - `ConnectionsRepository` encapsulates all Firestore reads/writes for:
    - Follow graph (followers/following).
    - Connection graph and requests.
    - Suggested users.
  - Reuses existing `UserModel` entity in `lib/models/user_model.dart` with added counters:
    - `followersCount`, `followingCount`, `connectionsCount`.
- **Notifications / FCM**
  - No client-side FCM send; notifications are still triggered by writes to `notifications` collection.
  - New connection-related events simply create documents with `type: "connection_request"` or `type: "request_accepted"`, which automatically:
    - Trigger the existing Cloud Function `pushOnNotificationCreated`.
    - Show in-app notifications via `PushNotificationsService`.
  - **Post Approval/Rejection Notification Routing**:
    - When a pending post is approved or rejected by an Admin, the status notification (`post_approved` or `post_rejected`) is explicitly routed to the Post Owner/Creator (`toUserId` set to `ownerId`, and `fromUserId` set to `adminId`).
    - Stale or duplicate `post_pending` notifications are automatically deleted from Firestore during status updates and background cleanup checks to ensure Admin notification screens are kept clean and no status notifications are mistakenly sent to the Admin who processed the action.

---

## 10. Advanced Messaging & Community Features (WhatsApp/Telegram Style)

- **Clean Architecture & BLoC Refactor**
  - **Migration**: Refactored the entire `chat` and `community` features from raw Provider streams to a strict Clean Architecture pattern (Domain Entities, Repositories, BLoCs).
  - **State Management**: `ConversationsBloc`, `MessagesBloc`, `GroupsListBloc`, and `GroupChatBloc` manage complex real-time messaging states gracefully, avoiding memory leaks and multiple stream subscription issues.

- **Real-Time 1-to-1 & Group Chats**
  - **Message Forwarding & Replying**: Users can swipe to reply to specific messages. Forwarding messages to other groups or direct chats is seamlessly supported.
  - **Message Deletion**: Users can delete messages for themselves or for everyone (within a 10-minute window).
  - **Reactions System**: 
    - Implemented a bottom sheet allowing users to add/remove emoji reactions (`❤️, 👍, 😂`, etc.) to any message.
    - Supports viewing who reacted and real-time updates.

- **Voice Messaging System**
  - Added a highly interactive `VoiceRecorderBar` widget replacing the standard text input when triggered.
  - Supports long-press to record, slide to cancel, lock to record hands-free, and dynamic wave visualizers.
  - Uploads `.m4a` files directly to Firebase Storage and renders them using a custom `VoiceMessagePlayer`.

- **Mute & Notification Control System**
  - Users can completely mute 1-to-1 conversations and Community Groups (options: 8 hours, 1 week, Always).
  - Visual indicators (`🔕`) instantly update across chat lists and AppBars using optimistic UI updates.
  - **Cloud Integration**: The `index.js` Cloud Function intercepts the notification payload, queries the `muteUntil` fields in Firestore, and silently skips sending Push Notifications to muted users, preserving battery and ensuring true silence.

- **Group Mentions (@Tagging)**
  - Users can trigger a live smart-suggestion overlay by typing `@` in any group chat.
  - The list live-filters group members as the user types.
  - The UI highlights mentioned users inside the message bubbles using custom `RichText` formatting (e.g., `@Name` with a primary color pill).
  - **Notification Engine**: Mentions inject `mentionedUserIds` into the payload, which triggers **High Priority Push Notifications** via Cloud Functions to alert the tagged users even if the group is otherwise muted.

- **Community Group Management**
  - **Admin Powers**: Group owners and admins can pin messages, manage group settings, and delete any message for everyone.
  - **Full-Screen Media Viewing**: Tap on images/videos to view them in a stunning full-screen hero animation with zooming capabilities.

---

## 11. Firestore Connection Resilience & Retry Mechanism

**Context & Issue**
- When a user scans a Community QR code or opens a deep link, the application resolves the invite token to a community or group by querying Firestore via `DeepLinkService`.
- Under unstable network conditions, or when Firestore encounters transient issues (such as socket timeouts or database cold-start delays), Firestore throws a transient `FirebaseException` with the code `unavailable` or `connection-failed`.
- This transient error would fail the deep link navigation flow immediately, throwing a user-facing error snackbar stating: `حدث خطأ: [cloud_firestore/unavailable] The service is currently unavailable. This is a most likely a transient condition and may be corrected by retrying with a backoff.`

**Solution**
- We added a private `_retry` helper method inside `DeepLinkService` that implements exponential backoff:
  - It catches any transient Firestore exception (`unavailable`, `transient`, or `connection-failed`).
  - It retries the operation up to 3 times, doubling the delay between attempts (`500ms`, `1000ms`, `2000ms`).
- All Firestore queries inside the navigation flow `_navigateToJoinFlow` are wrapped inside the `_retry` helper.
- This ensures robust handling of transient connection drops without any breaking changes to existing architecture or UI flow.

---

## 12. Community Leaving Flow & Member Count Fixes

**Context & Issues**
1. **Community visibility after leaving**: When a user left a community group (via the "Leave Group" action in `group_info_screen.dart`), the community still appeared in their list.
2. **Stale / Fake "28 members" count**: The community list showed a count of "28 members" when leaving a community instead of updating or showing the actual count.

**Root Cause Analysis**
1. When a user left a group, `leaveGroup()` was called which triggered `removeMember()`. This removed the user from the group's lists, but did not delete the community member document located at `communities/{communityId}/members/{userId}`. Since `watchUserCommunities()` streams community lists using `collectionGroup('members').where('userId', == userId)`, the community stayed visible to the user.
2. In `community_screen.dart` (around line 615), the UI had a fallback formula `(community.name.length * 3) + 7` triggered when the calculated member count was 0. For a community named "private" (7 characters), this returned exactly `28`.

**Solutions Implemented**
1. **Auto-remove Community Membership**: Updated `removeMember()` in `group_repository_impl.dart` to check if the group being left is the announcement group (`isAnnouncementOnly == true`). If so, it deletes the user's membership document from `communities/{communityId}/members/{userId}` and removes them from all other groups in that community.
2. **Correct Member Count**: Removed the fake fallback formula in `community_screen.dart` to strictly reflect the actual unique member count.

---

## 13. Spacing Correction in Community Card

**Context & Issue**
- The community card contained extra blank space at the bottom (below the groups list) and was not wrapping its contents tightly.

**Root Cause Analysis**
- In `community_screen.dart`, the `ListView.separated` which displays group tiles had no `padding` defined (leaving it `null`). In Flutter, a scrollable widget like `ListView` with a `null` padding automatically tries to apply bottom padding for screen safe areas (bottom notches/bars), which caused a large gap at the bottom of the card on modern mobile devices.

**Solutions Implemented**
- Modified `ListView.separated` inside `_CommunityExpansionCard` to specify `padding: EdgeInsets.zero`. This overrides the automatic safe-area padding detection and ensures that the card's height wraps the groups list dynamically. When new groups are added or removed, the card shrinks or expands precisely to fit the groups without any trailing blank space.

---

## 14. Storage Rules Alignment & Community Image Uploads

**Context & Issue**
- Image uploads for group settings/creation were failing silently, and the community creation screen lacked the ability to pick and upload community cover images.

**Root Cause Analysis**
- The security rules in `storage.rules` restrict write operations to paths matching `media/{userId}/{fileName}`. However, `uploadGroupImage()`, `uploadChatImage()`, and `uploadChatAudio()` in `StorageService` attempted to write to paths like `group_avatars/`, `chat_images/`, and `chat_audio/` respectively, causing Firebase Storage to throw "Permission Denied" exceptions.
- `CreateCommunityScreen` lacked the state, image picker, and upload invocation logic completely.

**Solutions Implemented**
- Modified the group, chat, and audio upload extension methods in `StorageService` to retrieve the current user's UID (using Firebase Auth) and format the upload paths as `media/$userId/...` to satisfy the security rule constraints.
- Integrated `ImagePicker` and `StorageService` in `CreateCommunityScreen` to allow admins to upload community cover images dynamically on community creation.

---

## 15. Join Requests Visibility & Theme Integration in Group Details

**Context & Issue**
- The "Pending Join Requests" tile was hidden for admins in private groups if there was no group description.
- The "Invite link" card and screen background did not match the theme, rendering as dark navy in light theme and keeping white card backgrounds in dark theme.

**Root Cause Analysis**
- In `group_info_screen.dart`, the `_buildInfoCard` (which contains the requests tile) was wrapped in a conditional block `if (g.description.isNotEmpty)`. This caused the requests tile to be hidden if the description was empty.
- `GroupInfoScreen` hardcoded `Colors.white` for its container cards (`_WhiteCard`) and `Color(0xFFF2F2F7)` for its scaffold background, causing styling mismatches on themed devices. The invite section correctly shifted using `ColorScheme.surface` but didn't match the hardcoded white cards in dark mode.

**Solutions Implemented**
- Refactored `group_info_screen.dart` to render `_buildInfoCard` if either the description is not empty OR the user is an admin (`if (g.description.isNotEmpty || isAdmin)`), rendering the divider conditionally.
- Refactored card backgrounds (`_WhiteCard`), page background (`Scaffold`), headers, and text styles in `GroupInfoScreen` to dynamically adapt to `Theme.of(context).brightness`.
- Aligned `GroupInviteSection` padding by removing redundant outer padding in `group_info_screen.dart`.

---

## 16. Community UI Enhancements: Sticky Header & Collapsible Lists

**Context & Issues**
1. **Scrolling Header**: Previously, the entire Community screen scrolled as a single view. The app bar, search bar, and filter chips scrolled off-screen, requiring users to scroll all the way back to search or change filters.
2. **Expanded Groups list**: By default, each community card was expanded on load, immediately displaying all its nested groups. This created a cluttered and long screen when multiple communities were present.

**Solutions Implemented**
1. **Sticky Header**: 
   - Created a reusable layout widget [StickyHeaderLayout](file:///t:/Project_v2-main/lib/widgets/sticky_header_layout.dart) that hosts a sticky `header` at the top and a scrollable `body` inside an `Expanded` layout.
   - Integrated this layout inside [community_screen.dart](file:///t:/Project_v2-main/lib/features/community/community_screen.dart) by wrapping the screen content inside `StickyHeaderLayout`.
   - This keeps the entire header section (AppBar, Search bar, filter chips) fixed at the top of the screen while the list of communities and standalone groups scrolls smoothly underneath it. This component can be reused across any screen in the application.
2. **Collapsible lists by default**:
   - Converted `_CommunityExpansionCard` from a `StatelessWidget` to a `StatefulWidget` to track its expanded state.
   - Configured its internal `ExpansionTile` to be closed by default (`initiallyExpanded: false`).
   - Added an animated expand/collapse chevron icon (`Icons.keyboard_arrow_down_rounded` when collapsed, `Icons.keyboard_arrow_up_rounded` when expanded) right next to the "Arrow Forward" detail button. This visually signals to the user that the community card can be expanded or collapsed to see its nested groups.

---

## 17. Chats Selection Mode: Multi-Select AppBar Upgrade

**Context & Issues**
- When entering chat selection mode (multi-selection) in the Conversations screen, the AppBar previously only displayed a "Delete" action icon.
- A new design requires a full suite of action icons to be displayed: Pin, Delete, Mute/Notifications, Archive, and More Options.
- The multi-select AppBar must remain fixed (sticky) at the top of the screen while scrolling through the chat list underneath.

**Solutions Implemented**
- **Action Icons Suite**: Modified [conversations_screen.dart](file:///T:/Project_v2-main/lib/features/chat/presentation/screens/conversations_screen.dart) inside `_buildSliverAppBar` to include the full suite of functional action buttons:
  - **Pin**: Toggles `pinnedBy.$userId` in Firestore. Pinned conversations are sorted to the top of the screen list with a 📌 icon badge.
  - **Delete**: Wires `_showBatchDeleteConfirmation` to call the `deleteConversationsBatch` repository method.
  - **Mute/Notifications**: Opens `MuteBottomSheet` and updates `muteUntil.$userId` in Firestore.
  - **Archive**: Toggles `archivedBy.$userId` in Firestore, hiding the conversation from the main list.
- **Sticky Scroll Behavior**: Verified and ensured the selection `SliverAppBar` inside the screen's `NestedScrollView` has `pinned: true` and `expandedHeight: kToolbarHeight`, maintaining its fixed placement at the top of the viewport during scrolls.
- **Data Models**: Added `archivedBy` (`Map<String, bool>`) and `pinnedBy` (`Map<String, DateTime>`) fields to [ConversationModel](file:///T:/Project_v2-main/lib/features/chat/data/models/conversation_model.dart) and [ConversationEntity](file:///T:/Project_v2-main/lib/features/chat/domain/entities/conversation_entity.dart) to persist per-user preferences in Firestore.
- **Notification Suppression**:
  - **Foreground**: Modified `_listenInAppNotifications` in [push_notifications_service.dart](file:///T:/Project_v2-main/lib/services/push_notifications_service.dart) to check for `archivedBy` and `muteUntil` fields in the conversation document. If active, the local notification is suppressed and marked read immediately.
  - **Background**: Modified `showBackgroundNotification` to perform the same checks defensively, blocking local notification delivery for muted/archived chats.
  - **Cloud Function**: Checked `archivedBy` alongside `muteUntil` in the `pushOnNotificationCreated` Cloud Function to skip sending background FCM push notifications entirely.




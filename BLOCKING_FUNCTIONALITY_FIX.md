# Blocking Functionality - Issues Found & Fixes

## Issues Identified

### ❌ Issue 1: Edge Function Doesn't Support `tools` Parameter
**Problem**: The iOS app sends `tools` (OpenAI's newer API), but the Edge Function only supported `functions` (legacy API).

**Fix Applied**: ✅ Updated Edge Function to support both `tools` and `functions` parameters.

---

### ❌ Issue 2: Message Encoding Missing Tool Calls
**Problem**: `OpenAIService` wasn't properly encoding `tool_calls` and `tool_call_id` in messages, so OpenAI couldn't see when tools were being used.

**Fix Applied**: ✅ Updated `ChatMessagePayload` to include `tool_calls` and `tool_call_id` fields.

---

### ❌ Issue 3: Tool Property Encoding
**Problem**: Tool properties with `enum` arrays weren't being encoded correctly.

**Fix Applied**: ✅ Updated `ToolPropertyPayload` to handle `enum` arrays properly.

---

### ⚠️ Issue 4: Blocked Status Not Persisted
**Problem**: The `areBadAppsBlocked` state resets to 0 every time the app restarts because it's only stored in memory.

**Status**: Not yet fixed - needs implementation (see below).

---

### ⚠️ Issue 5: No Actual iOS App Blocking
**Problem**: The code only tracks a state variable. It doesn't actually block apps on iOS.

**Status**: This requires iOS Screen Time API implementation (see below).

---

## Fixes Applied

### 1. Edge Function (`supabase/functions/openai-chat/index.ts`)
- ✅ Added `tools` parameter support to `RequestBody` interface
- ✅ Added logic to forward `tools` parameter to OpenAI API
- ✅ Supports both `tools` (newer) and `functions` (legacy) for compatibility

### 2. OpenAIService (`ScreenAI/Services/OpenAIService.swift`)
- ✅ Updated `ChatMessagePayload` to include `tool_calls` and `tool_call_id`
- ✅ Fixed message encoding to handle all message types properly
- ✅ Updated `ToolPropertyPayload` to handle `enum` arrays

---

## What Still Needs To Be Done

### 1. Persist Blocked Status to Database

**Current**: `areBadAppsBlocked` is only in memory, so it resets on app restart.

**Solution Options**:

**Option A**: Store in conversation metadata
```swift
// In executeFunction when set_blocked_status is called:
if let convId = conversationId {
    try await chatService.updateConversationMetadata(
        id: convId,
        metadata: ["blocked_status": blocked]
    )
}
// Load on app start:
if let metadata = conversation.metadata,
   let blocked = metadata["blocked_status"] as? Int {
    areBadAppsBlocked = blocked
}
```

**Option B**: Store in user's profile metadata (better for persistence across conversations)

**Option C**: Create separate `app_block_status` table (as originally planned)

---

### 2. Implement Actual iOS App Blocking

**Current**: Only tracks state - doesn't actually block apps.

**To Actually Block Apps**, you need to:

1. **Add Family Controls Framework**
   - Requires special entitlements from Apple
   - Needs App Store review approval

2. **Request Screen Time Authorization**
   ```swift
   import FamilyControls
   import ManagedSettings
   
   let authorizationCenter = AuthorizationCenter.shared
   try await authorizationCenter.requestAuthorization(for: .individual)
   ```

3. **Block Apps Using ManagedSettings**
   ```swift
   import ManagedSettings
   
   let shield = Activity Shield()
   shield.application.blockedApplications = [applicationToken]
   ManagedSettingsStore().shield.application = shield
   ```

**Note**: This is complex and requires:
- Apple Developer account
- Special entitlements
- App Store review (can't be done in TestFlight easily)
- User must approve Screen Time access

---

## Testing the Current Fixes

After deploying the updated Edge Function:

1. **Test tool calls work**:
   - Send a message asking Nudge to block apps
   - Check if `set_blocked_status` is called
   - Verify the response includes the tool call

2. **Check if blocking status updates**:
   - Check Settings view - status should show BLOCKED/NOT BLOCKED
   - However, it will reset on app restart until persistence is added

---

## Next Steps (Priority Order)

1. ✅ **Fix Edge Function** - DONE (needs redeployment)
2. ✅ **Fix message encoding** - DONE
3. ⬜ **Add blocked status persistence** - TODO
4. ⬜ **Implement actual iOS app blocking** - TODO (if needed)

---

## How to Deploy the Fixed Edge Function

Since you modified the Edge Function, you need to redeploy it:

### Via Dashboard:
1. Go to Supabase Dashboard → Edge Functions
2. Open `openai-chat` function
3. Replace the code with the updated version from `supabase/functions/openai-chat/index.ts`
4. Click "Deploy"

### Via CLI:
```bash
supabase functions deploy openai-chat
```

---

## Summary

**Fixed**:
- ✅ Edge Function now supports `tools` parameter
- ✅ Messages properly encode tool calls
- ✅ Tool properties with `enum` are handled correctly

**Still Needed**:
- ⬜ Persist blocked status to database (resets on app restart)
- ⬜ Implement actual iOS app blocking (if you want real blocking)

The blocking functionality should now **work for setting/getting the status**, but:
- Status won't persist across app restarts (until persistence is added)
- Apps aren't actually blocked (until Screen Time API is implemented)


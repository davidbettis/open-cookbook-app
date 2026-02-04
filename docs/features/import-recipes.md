# Import Recipes from Images/Websites

**Status:** Brainstorming

## Overview

Allow users to import recipes by:
1. Taking a photo or selecting an image (cookbook page, handwritten recipe, screenshot)
2. Pasting a URL from a recipe website

The app sends the content to Claude API for extraction and conversion to RecipeMD format.

## Cost Considerations

- Each Claude API call has a cost (input + output tokens)
- Image processing (vision) costs more than text
- Estimated cost per import: $0.01 - $0.05 depending on complexity
- Need to recoup costs while keeping friction low

---

## Economic Models

### Option 1: One-Time Unlock (Simplest)

**How it works:** User pays once (e.g., $4.99) to unlock the import feature forever.

| Pros | Cons |
|------|------|
| Simplest implementation | No ongoing revenue |
| No tracking needed | Risk if heavy users exceed revenue |
| One IAP to configure | Can't adjust pricing per usage |
| Users love "buy once" | May need to disable if costs spike |

**Implementation:** Single non-consumable IAP. Check `isPurchased` before allowing imports.

**Risk mitigation:** Add a soft daily limit (e.g., 20/day) to prevent abuse.

---

### Option 2: Import Packs (Consumable Credits)

**How it works:** User buys packs of imports (e.g., 10 imports for $1.99, 50 for $6.99).

| Pros | Cons |
|------|------|
| Revenue scales with usage | Must track remaining imports |
| Users only pay for what they use | More IAPs to configure |
| Can offer bulk discounts | Users may feel nickel-and-dimed |
| Predictable cost coverage | Need UI to show remaining credits |

**Implementation:**
- Consumable IAP
- Store import count in `@AppStorage` or Keychain
- Decrement on each successful import
- Simple integer tracking (not a "balance")

**Complexity:** Low-Medium. Just track a single integer locally.

---

### Option 3: Time-Based Passes

**How it works:** User buys time-limited access (e.g., 24-hour pass for $0.99, 7-day pass for $2.99).

| Pros | Cons |
|------|------|
| No per-import tracking | Risk of heavy use during window |
| Simple expiration check | Users may wait to batch imports |
| Good for occasional users | Less predictable revenue |
| Easy to understand | Need to show time remaining |

**Implementation:**
- Consumable IAP
- Store `passExpirationDate` in `@AppStorage`
- Check `Date() < passExpirationDate` before allowing imports

**Complexity:** Low. Just track one Date value.

---

### Option 4: Subscription (Apple Handles Everything)

**How it works:** Monthly ($1.99/mo) or yearly ($14.99/yr) subscription unlocks imports.

| Pros | Cons |
|------|------|
| Apple handles all billing | Overkill for single feature? |
| Recurring revenue | Higher user commitment |
| No local tracking needed | App Store review complexity |
| StoreKit 2 makes it easier | Users may resist subscriptions |

**Implementation:**
- Auto-renewable subscription IAP
- Use StoreKit 2 `Product.SubscriptionInfo`
- Check entitlement status

**Complexity:** Medium. StoreKit 2 simplifies but still more setup than one-time.

---

### Option 5: Freemium with Soft Limit

**How it works:** First 3-5 imports free, then require purchase (any model above).

| Pros | Cons |
|------|------|
| Users can try before buying | Must track free usage |
| Reduces purchase friction | Some users only use free tier |
| Demonstrates value | Need to handle "used all free" state |

**Implementation:**
- Track `freeImportsUsed` in `@AppStorage`
- After limit, prompt for purchase
- Combine with any paid model above

**Complexity:** Low additional complexity on top of chosen paid model.

---

### Option 6: Hybrid - Unlock + Daily Limit

**How it works:** One-time purchase ($3.99) unlocks feature with generous daily limit (e.g., 25/day).

| Pros | Cons |
|------|------|
| Simple purchase | Need to track daily usage |
| Predictable max cost exposure | Power users may hit limit |
| No ongoing purchase friction | Requires date-based reset logic |
| Users feel they "own" feature | |

**Implementation:**
- Non-consumable IAP
- Track `importsToday` and `lastImportDate` in `@AppStorage`
- Reset count when date changes

**Complexity:** Low. Two values to track, simple date comparison.

---

## Recommendation

**For minimum complexity:** Option 1 (One-Time Unlock) or Option 6 (Unlock + Daily Limit)

**For best cost coverage:** Option 2 (Import Packs) or Option 3 (Time Passes)

**Suggested approach:** Start with **Option 6 (Unlock + Daily Limit)**
- Single purchase keeps it simple
- Daily limit protects against cost overruns
- Users get a clear value proposition
- Can always add packs later if needed

### Suggested Pricing (Option 6)
- **Price:** $3.99 one-time
- **Daily limit:** 25 imports
- **Free trial:** 3 imports before purchase required

---

## Technical Implementation Notes

### StoreKit 2 Basics
```swift
// Check if purchased
let purchased = try await Product.products(for: ["com.app.importfeature"])
    .first?.currentEntitlement != nil

// Make purchase
let result = try await product.purchase()
```

### Tracking (if needed)
```swift
@AppStorage("freeImportsUsed") private var freeImportsUsed = 0
@AppStorage("importsToday") private var importsToday = 0
@AppStorage("lastImportDate") private var lastImportDate = ""

func canImport() -> Bool {
    resetDailyCountIfNeeded()
    if !hasPurchased && freeImportsUsed >= 3 { return false }
    if hasPurchased && importsToday >= 25 { return false }
    return true
}
```

### Claude API Integration
```swift
// Pseudocode
func importFromImage(_ image: UIImage) async throws -> Recipe {
    let base64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString()
    let response = try await claudeAPI.send(
        model: "claude-sonnet-4-20250514",
        messages: [.user(content: [
            .image(base64),
            .text("Extract this recipe in RecipeMD format...")
        ])]
    )
    return parseRecipeMD(response.text)
}
```

---

## Open Questions

1. Should URL imports cost the same as image imports? (URLs are cheaper to process)
2. Should failed imports count against limits?
3. Offline handling - queue imports for later?
4. Should there be a way to preview before "spending" an import?

---

## Files to Create/Modify (Future)

| File | Purpose |
|------|---------|
| `Core/Services/RecipeImportService.swift` | Claude API integration |
| `Core/Services/StoreKitManager.swift` | IAP handling |
| `Features/Import/Views/ImportRecipeView.swift` | UI for import flow |
| `Features/Import/Views/ImportSourcePicker.swift` | Choose image/URL |

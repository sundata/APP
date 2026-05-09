# Apple Review Response - ニュースNow

## Submission ID: 0b614a18-77dc-481a-b5b0-1f78b1f10f4b
**Date: May 5, 2026**

---

## Response to Guideline 2.1(b) - Performance - App Completeness

### Issue: In-App Purchase Products Not Loading

Dear Apple Review Team,

Thank you for the detailed feedback regarding the In-App Purchase functionality in ニュースNow (version 1.0, build 2).

#### Findings and Resolution

We have identified and resolved the issues with our In-App Purchase products:

**Root Causes Fixed:**
1. **StoreKit Configuration Issues** - Updated StoreKit2 implementation with proper error handling and async/await patterns
2. **Product ID Mismatch** - Verified all product IDs match exactly between App Store Connect and app bundle
3. **Sandbox Testing Environment** - Ensured proper sandbox certificate configuration
4. **Network Connectivity Handling** - Enhanced network error recovery for unstable connections

**Changes Made:**
- ✅ Implemented comprehensive error logging for IAP transactions
- ✅ Added retry logic for failed product loading
- ✅ Enhanced StoreKit delegate callbacks with proper completion handlers
- ✅ Verified Paid Apps Agreement is active in Business section of App Store Connect
- ✅ Tested IAP on sandbox environment with Test Flight - **All transactions successful**
- ✅ Added user-friendly error messages for payment failures
- ✅ Implemented transaction completion and restoration logic

**Testing Completed:**
- iPad Air 11-inch (M3) with iPadOS 26.4.2 - ✓ IAP Loading: Success
- iPhone models - ✓ IAP Loading: Success  
- Sandbox environment - ✓ All transactions processed successfully
- Network failure scenarios - ✓ Proper error handling implemented

#### Technical Details

**IAP Implementation:**
- StoreKit 2.0 framework with async/await
- Proper transaction queue management
- Transaction observer pattern for subscription monitoring
- Sandbox receipt validation

**Paid Apps Agreement:**
- ✓ Confirmed active in App Store Connect Business section
- ✓ Banking information updated
- ✓ Tax information verified

We have thoroughly tested the In-App Purchase functionality and confirm that:
- Products load correctly in sandbox environment
- Users can complete purchases without errors
- Transaction history is properly restored
- Error scenarios are handled gracefully

#### Ready for Review

The updated version is ready for review. We are confident that all In-App Purchase issues have been resolved and the app now meets guideline 2.1(b) requirements for app completeness.

If you have any questions or need additional technical details, please don't hesitate to reach out. We are happy to provide more information or conduct additional testing if needed.

Thank you for your thorough review and guidance.

Best regards,
**ニュースNow Development Team**

---

## Summary
- **Status:** ✅ Resolved
- **Version:** 1.0 (Build 3) 
- **Re-submission:** Ready
- **Testing:** Complete & Verified

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <os/lock.h>

// Derived from https://github.com/dayanch96/YTLite/blob/main/Sideloading.x, with
// the extra access-group consumers from YouMod (GPL-3.0)
// https://github.com/Tonwalter888/YouMod Files/Sideloading.x.
//
// Tweaks/IAmYouTube is linked into this same dylib and already hooks
// SSOKeychainHelper, SSOKeychainCore and
// -[NSFileManager containerURLForSecurityApplicationGroupIdentifier:]. Neither
// copy calls %orig, so hooking them here as well only means one copy is dead —
// do not add them back.
//
// A resigned app runs under a different team prefix, so every keychain access
// group YouTube's frameworks were built with is wrong. Each hook below swaps in
// the group the app actually has; if that lookup fails, it keeps the original
// value and the framework behaves as stock.

static NSString *LookupAccessGroupID(void) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: @"bundleSeedID",
        (__bridge id)kSecAttrService: @"",
        (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
    };
    CFDictionaryRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound) {
        if (result) {
            CFRelease(result);
            result = NULL;
        }
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    }
    NSString *accessGroup = nil;
    if (status == errSecSuccess && result) {
        id value = [(__bridge NSDictionary *)result objectForKey:(__bridge id)kSecAttrAccessGroup];
        if ([value isKindOfClass:[NSString class]]) accessGroup = value;
    }
    if (result) CFRelease(result);
    return accessGroup;
}

// The group never changes for the life of the process, so it is looked up once.
// Not dispatch_once: a lookup that fails early in launch is retried on the next
// call instead of being cached as nil. Two threads racing the first lookup
// both hit the keychain, which is harmless.
static NSString *accessGroupID(void) {
    static NSString *cached = nil;
    static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

    os_unfair_lock_lock(&lock);
    NSString *group = cached;
    os_unfair_lock_unlock(&lock);
    if (group) return group;

    group = LookupAccessGroupID();
    if (!group) return nil;

    os_unfair_lock_lock(&lock);
    if (!cached) cached = group;
    group = cached;
    os_unfair_lock_unlock(&lock);
    return group;
}

%group gSideload

%hook SSOFolsomKeychainUtils
- (id)sharedAccessGroup {
    NSString *group = accessGroupID();
    if (group) return group;
    return %orig;
}
%end

// Firebase / GoogleUtilities keychain storage.
%hook GULKeychainStorage
- (void)getObjectForKey:(id)key objectClass:(Class)objectClass accessGroup:(id)accessGroup completionHandler:(id)handler {
    NSString *group = accessGroupID() ?: accessGroup;
    %orig(key, objectClass, group, handler);
}
- (void)setObject:(id)object forKey:(id)key accessGroup:(id)accessGroup completionHandler:(id)handler {
    NSString *group = accessGroupID() ?: accessGroup;
    %orig(object, key, group, handler);
}
- (void)removeObjectForKey:(id)key accessGroup:(id)accessGroup completionHandler:(id)handler {
    NSString *group = accessGroupID() ?: accessGroup;
    %orig(key, group, handler);
}
- (void)getObjectFromKeychainForKey:(id)key objectClass:(Class)objectClass accessGroup:(id)accessGroup completionHandler:(id)handler {
    NSString *group = accessGroupID() ?: accessGroup;
    %orig(key, objectClass, group, handler);
}
- (id)keychainQueryWithKey:(id)key accessGroup:(id)accessGroup {
    NSString *group = accessGroupID() ?: accessGroup;
    return %orig(key, group);
}
%end

// Google Notifications Platform.
%hook GNPEncryptionConfiguration
- (id)initWithKeychainAccessGroup:(id)accessGroup {
    NSString *group = accessGroupID() ?: accessGroup;
    return %orig(group);
}
- (id)keychainAccessGroup {
    NSString *group = accessGroupID();
    if (group) return group;
    return %orig;
}
%end

%hook FIRInstallationsStore
- (id)initWithSecureStorage:(id)storage accessGroup:(id)accessGroup {
    NSString *group = accessGroupID() ?: accessGroup;
    return %orig(storage, group);
}
- (id)accessGroup {
    NSString *group = accessGroupID();
    if (group) return group;
    return %orig;
}
%end

%hook CHMConfiguration
- (void)setKeychainAccessGroup:(id)accessGroup {
    NSString *group = accessGroupID() ?: accessGroup;
    %orig(group);
}
- (id)keychainAccessGroup {
    NSString *group = accessGroupID();
    if (group) return group;
    return %orig;
}
%end

%end

%ctor {
    BOOL isAppStoreApp = [[NSFileManager defaultManager] fileExistsAtPath:[[NSBundle mainBundle] appStoreReceiptURL].path];
    if (!isAppStoreApp) {
        %init(gSideload);
    }
}

"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteUserAccount = exports.initiateWithdrawal = exports.updateSellerRating = exports.onMessageCreated = exports.updateListingExpiry = exports.generatePickupOTP = exports.creditWallet = exports.sendOTP = exports.confirmPickup = exports.processWalletPayment = exports.initiateEscrow = void 0;
const admin = require("firebase-admin");
const functions = require("firebase-functions");
admin.initializeApp();
const db = admin.firestore();
const fcm = admin.messaging();
/**
 * 1. initiateEscrow (callable function):
 */
exports.initiateEscrow = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const { orderId, seerbitRef } = data;
    if (!orderId || !seerbitRef) {
        throw new functions.https.HttpsError("invalid-argument", "Missing orderId or seerbitRef.");
    }
    const uid = context.auth.uid;
    const orderRef = db.collection("orders").doc(orderId);
    await db.runTransaction(async (transaction) => {
        const orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Order not found.");
        }
        const orderData = orderDoc.data();
        if (orderData.buyerId !== uid) {
            throw new functions.https.HttpsError("permission-denied", "You are not the buyer of this order.");
        }
        if (orderData.status !== "pending") {
            throw new functions.https.HttpsError("failed-precondition", "Order status is not pending.");
        }
        transaction.update(orderRef, {
            status: "escrowHeld",
            seerbitRef: seerbitRef,
        });
        const txRef = db.collection("transactions").doc(uid).collection("history").doc();
        transaction.set(txRef, {
            id: txRef.id,
            userId: uid,
            type: "paymentSent",
            amount: orderData.amount + orderData.platformFee,
            description: `Payment for ${orderData.listingTitle}`,
            seerbitRef: seerbitRef,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    const orderDoc = await orderRef.get();
    const orderData = orderDoc.data();
    await notifyUser(orderData.sellerId, "Payment received!", "Payment received! Buyer will pick up soon.");
    await notifyUser(orderData.buyerId, "Payment confirmed!", "Payment confirmed! Contact seller to arrange pickup.");
    return { success: true };
});
/**
 * 2. processWalletPayment
 */
exports.processWalletPayment = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const { orderId } = data;
    if (!orderId) {
        throw new functions.https.HttpsError("invalid-argument", "Missing orderId.");
    }
    const uid = context.auth.uid;
    const orderRef = db.collection("orders").doc(orderId);
    const userRef = db.collection("users").doc(uid);
    await db.runTransaction(async (transaction) => {
        const [orderDoc, userDoc] = await Promise.all([
            transaction.get(orderRef),
            transaction.get(userRef),
        ]);
        if (!orderDoc.exists || !userDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Order or User not found.");
        }
        const orderData = orderDoc.data();
        const userData = userDoc.data();
        if (orderData.buyerId !== uid) {
            throw new functions.https.HttpsError("permission-denied", "You are not the buyer.");
        }
        if (orderData.status !== "pending") {
            throw new functions.https.HttpsError("failed-precondition", "Order status is not pending.");
        }
        const totalCost = orderData.amount + orderData.platformFee;
        const currentBalance = userData.walletBalance || 0;
        if (currentBalance < totalCost) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient wallet balance.");
        }
        transaction.update(userRef, {
            walletBalance: currentBalance - totalCost,
        });
        transaction.update(orderRef, {
            status: "escrowHeld",
        });
        const txRef = db.collection("transactions").doc(uid).collection("history").doc();
        transaction.set(txRef, {
            id: txRef.id,
            userId: uid,
            type: "paymentSent",
            amount: totalCost,
            description: `Wallet Payment for ${orderData.listingTitle}`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    const orderDoc = await orderRef.get();
    const orderData = orderDoc.data();
    await notifyUser(orderData.sellerId, "Payment received!", "Payment received! Buyer will pick up soon.");
    await notifyUser(orderData.buyerId, "Payment confirmed!", "Payment confirmed! Contact seller to arrange pickup.");
    return { success: true };
});
/**
 * 3. confirmPickup
 */
exports.confirmPickup = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const { orderId, otp } = data;
    if (!orderId || !otp) {
        throw new functions.https.HttpsError("invalid-argument", "Missing orderId or otp.");
    }
    const uid = context.auth.uid;
    const orderRef = db.collection("orders").doc(orderId);
    const sellerRef = db.collection("users").doc(uid);
    const adminWalletRef = db.collection("platform").doc("adminWallet");
    await db.runTransaction(async (transaction) => {
        const orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Order not found.");
        }
        const orderData = orderDoc.data();
        if (orderData.sellerId !== uid) {
            throw new functions.https.HttpsError("permission-denied", "You are not the seller of this order.");
        }
        const storedOtp = orderData.pickupOTP;
        if (!storedOtp || storedOtp.toString().toLowerCase() !== otp.toString().toLowerCase()) {
            throw new functions.https.HttpsError("invalid-argument", "Invalid OTP.");
        }
        if (orderData.status !== "escrowHeld") {
            throw new functions.https.HttpsError("failed-precondition", "Order is not in escrowHeld state.");
        }
        const sellerAmount = orderData.amount;
        const platformFee = orderData.platformFee;
        transaction.update(orderRef, {
            status: "completed",
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (sellerAmount > 0) {
            transaction.update(sellerRef, {
                walletBalance: admin.firestore.FieldValue.increment(sellerAmount),
            });
            const sellerTxRef = db.collection("transactions").doc(uid).collection("history").doc();
            transaction.set(sellerTxRef, {
                id: sellerTxRef.id,
                userId: uid,
                type: "paymentReceived",
                amount: sellerAmount,
                description: `Revenue from ${orderData.listingTitle}`,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        transaction.set(adminWalletRef, {
            balance: admin.firestore.FieldValue.increment(platformFee),
        }, { merge: true });
    });
    const orderDoc = await orderRef.get();
    const orderData = orderDoc.data();
    // Notify buyer of successful pickup
    await notifyUser(orderData.buyerId, "Pickup confirmed!", "Pickup confirmed! Please rate your experience.", `/rate/${orderId}`);
    // Notify seller that revenue was credited
    await notifyUser(orderData.sellerId, "Revenue Credited!", `You've earned UGX ${orderData.amount} from ${orderData.listingTitle}.`, "/wallet");
    return { success: true };
});
/**
 * 4. sendOTP (callable):
 *    Generates a 6-digit OTP and sends it via FCM for email/phone verification.
 */
exports.sendOTP = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const { type, value } = data; // type: 'email' | 'phone', value: the actual identifier
    if (!type || !value) {
        throw new functions.https.HttpsError("invalid-argument", "Missing type or value.");
    }
    const uid = context.auth.uid;
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiry = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000)); // 10 mins
    const userRef = db.collection("users").doc(uid);
    if (type === "email") {
        await userRef.update({
            emailOTP: otp,
            emailOTPExpiry: expiry,
        });
        await notifyUser(uid, "Email Verification Code", `Your 6-digit verification code is: ${otp}`);
    }
    else {
        await userRef.update({
            phoneOTP: otp,
            phoneOTPExpiry: expiry,
        });
        await notifyUser(uid, "Phone Verification Code", `Your 6-digit verification code is: ${otp}`);
    }
    return { success: true, otp: "Code sent via push notification" };
});
/**
 * 5. creditWallet
 */
exports.creditWallet = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const { amount, seerbitRef, transactionRef } = data;
    const actualRef = seerbitRef || transactionRef;
    if (!amount || amount <= 0 || !actualRef) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid amount or seerbit/tx ref.");
    }
    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);
    // TODO: Add SeerBit webhook server-side API verification here in Production
    await db.runTransaction(async (transaction) => {
        transaction.update(userRef, {
            walletBalance: admin.firestore.FieldValue.increment(amount),
        });
        const txRef = db.collection("transactions").doc(uid).collection("history").doc();
        transaction.set(txRef, {
            id: txRef.id,
            userId: uid,
            type: "topUp",
            amount: amount,
            description: "Wallet Top Up via SeerBit",
            seerbitRef: actualRef,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    return { success: true };
});
/**
 * 5. generatePickupOTP
 */
exports.generatePickupOTP = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const { orderId } = data;
    if (!orderId) {
        throw new functions.https.HttpsError("invalid-argument", "Missing orderId.");
    }
    const uid = context.auth.uid;
    const orderRef = db.collection("orders").doc(orderId);
    const orderDoc = await orderRef.get();
    if (!orderDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Order not found.");
    }
    if (orderDoc.data().buyerId !== uid) {
        throw new functions.https.HttpsError("permission-denied", "Only the buyer can generate the OTP.");
    }
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    await orderRef.update({
        pickupOTP: otp,
    });
    return { otp };
});
/**
 * 6. updateListingExpiry (Scheduled)
 * Runs every 5 minutes
 */
exports.updateListingExpiry = functions.pubsub.schedule("every 5 minutes").onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const expiredListingsSnapshot = await db.collection("listings")
        .where("status", "==", "active")
        .where("pickupWindowEnd", "<", now)
        .get();
    if (expiredListingsSnapshot.empty) {
        return null;
    }
    const batch = db.batch();
    expiredListingsSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, { status: "expired" });
    });
    await batch.commit();
    console.log(`Updated ${expiredListingsSnapshot.size} listings to expired.`);
    return null;
});
/**
 * 7. onMessageCreated (Firestore Trigger)
 * Sends notification to recipient when a new message is sent
 */
exports.onMessageCreated = functions.firestore
    .document("chats/{chatId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
    const messageData = snapshot.data();
    if (!messageData)
        return null;
    const recipientId = messageData.recipientId;
    const senderName = messageData.senderName || "Someone";
    const text = messageData.text || "Sent a message";
    const chatId = context.params.chatId;
    await notifyUser(recipientId, `New message from ${senderName}`, text, `/chat/${chatId}`);
    return null;
});
/**
 * 7. updateSellerRating
 */
exports.updateSellerRating = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const { sellerId, ratingId } = data;
    if (!sellerId || !ratingId) {
        throw new functions.https.HttpsError("invalid-argument", "Missing sellerId or ratingId.");
    }
    const sellerRef = db.collection("users").doc(sellerId);
    const ratingRef = db.collection("ratings").doc(ratingId);
    await db.runTransaction(async (transaction) => {
        const [sellerDoc, ratingDoc] = await Promise.all([
            transaction.get(sellerRef),
            transaction.get(ratingRef),
        ]);
        if (!sellerDoc.exists || !ratingDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Seller or Rating not found.");
        }
        const sellerData = sellerDoc.data();
        const ratingData = ratingDoc.data();
        const currentAvg = sellerData.averageRating || 0;
        const currentTotal = sellerData.totalRatings || 0;
        const newReviewAvg = (ratingData.foodQualityRating + ratingData.reliabilityRating) / 2;
        const newTotal = currentTotal + 1;
        const newAverage = ((currentAvg * currentTotal) + newReviewAvg) / newTotal;
        transaction.update(sellerRef, {
            averageRating: newAverage,
            totalRatings: newTotal,
        });
    });
    return { success: true };
});
/**
 * Helper: Notification sender
 */
async function notifyUser(userId, title, body, deepLink) {
    console.log(`notifyUser triggered for ${userId}: ${title}`);
    try {
        // 1. Create Firestore notification
        const notificationRef = db.collection("notifications").doc(userId).collection("items").doc();
        let type = "other";
        const lowerTitle = title.toLowerCase();
        if (lowerTitle.includes("payment"))
            type = "payment_received";
        else if (lowerTitle.includes("pickup"))
            type = "pickup_confirmed";
        else if (lowerTitle.includes("expired"))
            type = "listing_expiry";
        else if (lowerTitle.includes("message"))
            type = "new_message";
        else if (lowerTitle.includes("order"))
            type = "new_order";
        else if (lowerTitle.includes("verification"))
            type = "auth_otp";
        const notificationData = {
            id: notificationRef.id,
            title,
            body,
            type,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            deepLink: deepLink || "",
            data: deepLink ? { route: deepLink } : {},
        };
        await notificationRef.set(notificationData);
        console.log(`Firestore notification created: ${notificationRef.id}`);
        // 2. Try to send push notification
        const userDoc = await db.collection("users").doc(userId).get();
        if (userDoc.exists) {
            const userData = userDoc.data();
            const fcmToken = userData.fcmToken;
            if (fcmToken) {
                const message = {
                    notification: { title, body },
                    token: fcmToken,
                    android: {
                        priority: "high",
                        notification: {
                            channelId: "food_loop_channel",
                            clickAction: "FLUTTER_NOTIFICATION_CLICK",
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                alert: { title, body },
                                sound: "default",
                                badge: 1,
                            },
                        },
                    },
                    data: {
                        type,
                        route: deepLink || "",
                    },
                };
                const response = await fcm.send(message);
                console.log(`Successfully sent push notification to ${userId}: ${response}`);
            }
            else {
                console.warn(`No FCM token found for user ${userId}`);
            }
        }
        else {
            console.warn(`User document ${userId} not found for push notification`);
        }
    }
    catch (error) {
        console.error("Failed to send notification:", error);
    }
}
/**
 * 8. initiateWithdrawal (callable):
 */
exports.initiateWithdrawal = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const { amount, phoneNumber } = data;
    if (!amount || amount < 1000 || !phoneNumber) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid amount or phone number.");
    }
    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);
    await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
            throw new functions.https.HttpsError("not-found", "User not found.");
        }
        const currentBalance = userDoc.data().walletBalance || 0;
        if (currentBalance < amount) {
            throw new functions.https.HttpsError("failed-precondition", "Insufficient funds.");
        }
        transaction.update(userRef, {
            walletBalance: currentBalance - amount,
        });
        const txRef = db.collection("transactions").doc(uid).collection("history").doc();
        transaction.set(txRef, {
            id: txRef.id,
            userId: uid,
            type: "withdrawal",
            amount: amount,
            description: `Withdrawal to ${phoneNumber}`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            status: "pending",
        });
        // Notify admin or log to a central withdrawals collection
        const adminWithdrawalRef = db.collection("admin_withdrawals").doc();
        transaction.set(adminWithdrawalRef, {
            id: adminWithdrawalRef.id,
            userId: uid,
            amount: amount,
            phoneNumber: phoneNumber,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            status: "pending",
        });
    });
    return { success: true };
});
/**
 * 9. deleteUserAccount (callable):
 *    Deletes all user data: Firestore docs, Storage files, Auth user.
 */
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = context.auth.uid;
    try {
        const batch = db.batch();
        // Delete user document
        batch.delete(db.collection("users").doc(uid));
        // Delete listings
        const listings = await db.collection("listings").where("sellerId", "==", uid).get();
        listings.docs.forEach((doc) => batch.delete(doc.ref));
        // Delete expiry items subcollection
        const expiryItems = await db.collection("expiryItems").doc(uid).collection("items").get();
        expiryItems.docs.forEach((doc) => batch.delete(doc.ref));
        batch.delete(db.collection("expiryItems").doc(uid));
        await batch.commit();
        // Delete Storage files (profile image)
        try {
            const bucket = admin.storage().bucket();
            await bucket.file(`profiles/${uid}.jpg`).delete();
        }
        catch (storageError) {
            // File may not exist, continue
            console.warn("Storage file not found (may not exist):", storageError);
        }
        // Delete Firebase Auth user last
        await admin.auth().deleteUser(uid);
        return { success: true };
    }
    catch (error) {
        console.error("deleteUserAccount error:", error);
        throw new functions.https.HttpsError("internal", "Failed to delete account.");
    }
});
//# sourceMappingURL=index.js.map
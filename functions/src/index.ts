import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

admin.initializeApp();
const db = admin.firestore();
const fcm = admin.messaging();

/**
 * 1. initiateEscrow (callable function):
 */
export const initiateEscrow = functions.https.onCall(async (data, context) => {
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

    const orderData = orderDoc.data()!;
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
  const orderData = orderDoc.data()!;
  
  await notifyUser(orderData.sellerId, "Payment received!", "Payment received! Buyer will pick up soon.");
  await notifyUser(orderData.buyerId, "Payment confirmed!", "Payment confirmed! Contact seller to arrange pickup.");

  return { success: true };
});

/**
 * 1b. confirmFlutterwavePayment (callable function):
 * Verifies the transaction with Flutterwave API and updates the order status.
 */
export const confirmFlutterwavePayment = functions.https.onCall(async (data: any, context) => {
  // 1. Auth check
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in to confirm payment.");
  }

  const { orderId, transactionRef, flutterwaveTransactionId } = data;
  const userId = context.auth.uid;

  if (!orderId || !transactionRef || !flutterwaveTransactionId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required payment details.");
  }

  // 2. Fetch the order
  const orderRef = db.collection("orders").doc(orderId);
  const orderDoc = await orderRef.get();
  
  if (!orderDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Order not found.");
  }

  const order = orderDoc.data()!;

  // 3. Verify caller is the buyer
  if (order.buyerId !== userId) {
    throw new functions.https.HttpsError("permission-denied", "You are not the buyer of this order.");
  }

  // 4. Idempotency check — if already processed, return success
  if (order.status === "escrowHeld" || order.status === "completed") {
    return { success: true, message: "Payment already processed." };
  }

  // 5. Verify with Flutterwave API
  try {
    const secretKey = functions.config().flutterwave?.secret_key || "FLWSECK_TEST-567548fac5474af72669d8fb026e8da6-X";
    const fwResponse = await fetch(
      `https://api.flutterwave.com/v3/transactions/${flutterwaveTransactionId}/verify`,
      {
        headers: {
          Authorization: `Bearer ${secretKey}`,
        },
      }
    );
    
    const fwData: any = await fwResponse.json();

    if (
      fwData.status !== "success" ||
      fwData.data.status !== "successful" ||
      fwData.data.tx_ref !== transactionRef ||
      fwData.data.amount < order.amount ||
      fwData.data.currency !== "UGX"
    ) {
      console.error("Flutterwave verification failed:", fwData);
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Payment verification failed with Flutterwave."
      );
    }

    // 6. Update order status to escrowHeld
    await db.runTransaction(async (transaction) => {
      transaction.update(orderRef, {
        status: "escrowHeld",
        flutterwaveRef: transactionRef,
        flutterwaveTransactionId: flutterwaveTransactionId,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Log the transaction history
      const txRef = db.collection("transactions").doc(userId).collection("history").doc();
      transaction.set(txRef, {
        id: txRef.id,
        userId: userId,
        type: "paymentSent",
        amount: order.amount + (order.platformFee || 0),
        description: `Payment for ${order.listingTitle}`,
        flutterwaveRef: transactionRef,
        flutterwaveTransactionId: flutterwaveTransactionId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // 7. Notify participants
    await notifyUser(order.sellerId, "Payment received! 💰", `${order.buyerName} paid for "${order.listingTitle}". Arrange pickup!`);
    await notifyUser(userId, "Payment confirmed! ✅", "Your payment was successful. You can now arrange pickup with the seller.");

    return { success: true };

  } catch (error: any) {
    console.error("Error in confirmFlutterwavePayment:", error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError("internal", error.message || "Failed to confirm payment.");
  }
});


/**
 * 2. processWalletPayment
 */
export const processWalletPayment = functions.https.onCall(async (data, context) => {
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

    const orderData = orderDoc.data()!;
    const userData = userDoc.data()!;

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
  const orderData = orderDoc.data()!;

  await notifyUser(orderData.sellerId, "Payment received!", "Payment received! Buyer will pick up soon.");
  await notifyUser(orderData.buyerId, "Payment confirmed!", "Payment confirmed! Contact seller to arrange pickup.");

  return { success: true };
});

/**
 * 3. confirmPickup
 */
export const confirmPickup = functions.https.onCall(async (data, context) => {
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

    const orderData = orderDoc.data()!;
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
  const orderData = orderDoc.data()!;
  
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
export const sendOTP = functions.https.onCall(async (data, context) => {
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
  } else {
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
export const creditWallet = functions.https.onCall(async (data, context) => {
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
export const generatePickupOTP = functions.https.onCall(async (data, context) => {
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

  if (orderDoc.data()!.buyerId !== uid) {
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
export const updateListingExpiry = functions.pubsub.schedule("every 5 minutes").onRun(async (context) => {
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
 * 6b. onOrderCreated (Firestore Trigger)
 * Automatically notifies the seller when a new order is created (including free claims).
 */
export const onOrderCreated = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snapshot, context) => {
    const orderData = snapshot.data();
    if (!orderData) return null;

    const sellerId = orderData.sellerId;
    const buyerName = orderData.buyerName || "Someone";
    const listingTitle = orderData.listingTitle || "food";
    const isFree = orderData.amount === 0;

    await notifyUser(
      sellerId,
      isFree ? "New Claim! 🎁" : "New Order! 🍴",
      `${buyerName} has ${isFree ? "claimed" : "ordered"} "${listingTitle}".`,
      "/orders"
    );

    return null;
  });

/**
 * 7. onMessageCreated (Firestore Trigger)
 * Sends notification to recipient when a new message is sent
 */
export const onMessageCreated = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const messageData = snapshot.data();
    if (!messageData) return null;

    let recipientId = messageData.recipientId;
    const senderName = messageData.senderName || "Someone";
    const text = messageData.text || "Sent a message";
    const chatId = context.params.chatId;

    // Fallback: If recipientId is missing in the message, get it from the chat thread participants
    if (!recipientId) {
      console.log(`recipientId missing in message ${context.params.messageId}, fetching chat thread ${chatId}`);
      const chatDoc = await db.collection("chats").doc(chatId).get();
      if (chatDoc.exists) {
        const participants = chatDoc.data()?.participants || [];
        recipientId = participants.find((id: string) => id !== messageData.senderId);
      }
    }

    if (!recipientId) {
      console.error(`Could not determine recipient for message ${context.params.messageId}`);
      return null;
    }

    await notifyUser(
      recipientId,
      `New message from ${senderName}`,
      text,
      `/chat/${chatId}`
    );

    return null;
  });

/**
 * 7. updateSellerRating
 */
export const updateSellerRating = functions.https.onCall(async (data, context) => {
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

    const sellerData = sellerDoc.data()!;
    const ratingData = ratingDoc.data()!;

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
async function notifyUser(userId: string, title: string, body: string, deepLink?: string) {
  if (!userId) {
    console.error("notifyUser called without userId");
    return;
  }

  console.log(`[Notification] Triggered for ${userId}: "${title}"`);
  
  try {
    // 1. Create Firestore notification (for the in-app notification list)
    const notificationRef = db.collection("notifications").doc(userId).collection("items").doc();
    
    let type = "other";
    const lowerTitle = title.toLowerCase();
    const lowerBody = body.toLowerCase();

    if (lowerTitle.includes("payment") || lowerBody.includes("paid")) {
      type = "payment_received";
    } else if (lowerTitle.includes("pickup") || lowerBody.includes("pickup")) {
      type = "pickup_confirmed";
    } else if (lowerTitle.includes("expired")) {
      type = "listing_expiry";
    } else if (lowerTitle.includes("message") || lowerBody.includes("message")) {
      type = "new_message";
    } else if (lowerTitle.includes("order") || lowerTitle.includes("confirmed")) {
      type = "order_confirmed";
    } else if (lowerTitle.includes("verification")) {
      type = "auth_otp";
    }

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
    console.log(`[Notification] Firestore doc created: ${notificationRef.id} for user ${userId}`);

    // 2. Try to send push notification via FCM
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      console.warn(`[Notification] User document ${userId} not found in /users collection`);
      return;
    }

    const userData = userDoc.data()!;
    const fcmToken = userData.fcmToken;
    
    if (!fcmToken) {
      console.warn(`[Notification] No fcmToken found for user ${userId}`);
      return;
    }

    const message: any = {
      notification: { title, body },
      token: fcmToken,
      android: {
        priority: "high",
        notification: {
          channelId: "food_loop_channel",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          sound: "default",
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
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    const response = await fcm.send(message);
    console.log(`[Notification] FCM push sent successfully to ${userId}. Response: ${response}`);
    
  } catch (error) {
    console.error("[Notification] Error sending notification:", error);
  }
}

/**
 * 8. initiateWithdrawal (callable):
 */
export const initiateWithdrawal = functions.https.onCall(async (data, context) => {
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

    const currentBalance = userDoc.data()!.walletBalance || 0;
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
export const deleteUserAccount = functions.https.onCall(async (data, context) => {
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
    } catch (storageError) {
      // File may not exist, continue
      console.warn("Storage file not found (may not exist):", storageError);
    }

    // Delete Firebase Auth user last
    await admin.auth().deleteUser(uid);

    return { success: true };
  } catch (error) {
    console.error("deleteUserAccount error:", error);
    throw new functions.https.HttpsError("internal", "Failed to delete account.");
  }
});

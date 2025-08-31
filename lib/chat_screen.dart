import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> messages = [];
  bool _isLoading = false;
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  /// ✅ Load messages from Firestore (fallback: SharedPreferences)
  Future<void> _loadMessages() async {
    try {
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection("users")
            .doc(user!.uid)
            .collection("messages")
            .orderBy("timestamp", descending: false)
            .get();

        setState(() {
          messages = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              "sender": data['sender']?.toString() ?? "unknown",
              "text": data['text']?.toString() ?? "",
            };
          }).toList();
        });
      } else {
        final prefs = await SharedPreferences.getInstance();
        final savedMessages = prefs.getStringList('chat_messages') ?? [];
        setState(() {
          messages = savedMessages.map((msg) {
            final decoded = jsonDecode(msg);
            return {
              "sender": decoded['sender']?.toString() ?? "unknown",
              "text": decoded['text']?.toString() ?? "",
            };
          }).toList();
        });
      }
    } catch (e) {
      print("Error loading messages: $e");
      setState(() {
        messages = [];
      });
    }
  }

  /// ✅ Save messages to Firestore + SharedPreferences
  Future<void> _saveMessages() async {
    try {
      if (user != null) {
        final batch = FirebaseFirestore.instance.batch();
        final userMessagesRef = FirebaseFirestore.instance
            .collection("users")
            .doc(user!.uid)
            .collection("messages");

        // Clear old messages
        final oldDocs = await userMessagesRef.get();
        for (var doc in oldDocs.docs) {
          batch.delete(doc.reference);
        }

        // Save current messages
        for (var msg in messages) {
          final docRef = userMessagesRef.doc();
          batch.set(docRef, {
            "sender": msg['sender'],
            "text": msg['text'],
            "timestamp": FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      // Save locally as backup
      final prefs = await SharedPreferences.getInstance();
      final msgList = messages.map((msg) => jsonEncode(msg)).toList();
      await prefs.setStringList('chat_messages', msgList);
    } catch (e) {
      print("Error saving messages: $e");
    }
  }

  /// ✅ Send message to Flask backend
  Future<void> sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      messages.add({"sender": "user", "text": message});
      _isLoading = true;
    });
    await _saveMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final response = await http
          .post(
        Uri.parse('http://10.0.2.2:5000/chat'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botReply = data['reply'] ?? data['response'] ?? 'No reply';
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          messages.add({"sender": "bot", "text": botReply});
        });
        _saveMessages();
      } else {
        print("Server error: ${response.statusCode} - ${response.body}");
        setState(() {
          messages.add({
            "sender": "bot",
            "text": "Error: Server responded with ${response.statusCode}"
          });
        });
        _saveMessages();
      }
    } catch (e) {
      print("API exception: $e");
      setState(() {
        messages.add({
          "sender": "bot",
          "text": e.toString().contains('Timeout')
              ? "Error: Connection timed out!"
              : "Error: Failed to connect to the server!"
        });
      });
      _saveMessages();
    } finally {
      setState(() {
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildQuickReplies() {
    return Wrap(
      spacing: 5,
      children: ["Tell me a joke", "Give me a quote", "Help with commands"]
          .map((suggestion) {
        return ActionChip(
          label: Text(suggestion),
          onPressed: () => sendMessage(suggestion),
        );
      }).toList(),
    );
  }

  Widget _buildChatBubble(Map<String, String> message) {
    final isUser = message["sender"] == "user";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userBg = isDark ? Colors.blue.withOpacity(0.8) : Colors.blue.shade100;
    final userText = isDark ? Colors.white : Colors.black;

    final botBg = isDark ? Colors.black.withOpacity(0.7) : Colors.grey.shade200;
    final botText = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment:
      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            padding: const EdgeInsets.all(10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              color: isUser ? userBg : botBg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: isUser
                    ? const Radius.circular(12)
                    : const Radius.circular(0),
                bottomRight: isUser
                    ? const Radius.circular(0)
                    : const Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? "You" : "ZenBot",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isUser ? userText : botText),
                ),
                const SizedBox(height: 5),
                Text(message["text"]!,
                    style: TextStyle(color: isUser ? userText : botText)),
              ],
            ),
          ),
        ),
        if (!isUser && !message["text"]!.contains("Error"))
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 4),
            child: _buildQuickReplies(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: const AssetImage("assets/logo.png"),
                radius: 28,
                backgroundColor: Colors.transparent,
              ),
              const SizedBox(width: 15),
              Text(
                "ZenBot",
                style: const TextStyle(
                  fontFamily: 'Cormorant',
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              setState(() {
                messages.clear();
              });
              _saveMessages();
            },
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: PopupMenuButton<String>(
              icon: FirebaseAuth.instance.currentUser?.photoURL != null
                  ? CircleAvatar(
                backgroundImage:
                NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!),
              )
                  : CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  FirebaseAuth.instance.currentUser?.email?[0]
                      .toUpperCase() ??
                      "?",
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacementNamed('/');
                } else if (value == 'settings') {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) {
                      final isDarkMode =
                          Provider.of<ThemeProvider>(context, listen: false)
                              .isDarkMode;
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.settings, color: Colors.black),
                                SizedBox(width: 10),
                                Text(
                                  'Settings',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(thickness: 1, height: 20),
                            ListTile(
                              leading: const Icon(Icons.brightness_6),
                              title: const Text('Dark Mode'),
                              trailing: Consumer<ThemeProvider>(
                                builder: (context, themeProvider, _) => Switch(
                                  value: themeProvider.isDarkMode,
                                  onChanged: (value) {
                                    themeProvider.toggleTheme(value);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.black),
                      SizedBox(width: 10),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.black),
                      SizedBox(width: 10),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/bot.jpg", fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length + (_isLoading ? 1 : 0),
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    itemBuilder: (context, index) {
                      if (_isLoading && index == messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 10),
                                Text("ZenBot is typing..."),
                              ],
                            ),
                          ),
                        );
                      }
                      final message = messages[index];
                      return TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 500),
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildChatBubble(message),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: Colors.black),
                        onPressed: () {
                          // File upload logic (future extension)
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(
                            color: Theme.of(context).brightness ==
                                Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                          decoration: InputDecoration(
                            labelText: "Enter message",
                            labelStyle: TextStyle(
                              color: Theme.of(context).brightness ==
                                  Brightness.dark
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).brightness ==
                                Brightness.dark
                                ? Colors.grey[600]
                                : Colors.white.withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () {
                          if (_controller.text.isNotEmpty) {
                            sendMessage(_controller.text);
                            _controller.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

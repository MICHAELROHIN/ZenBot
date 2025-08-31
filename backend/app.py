from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from dotenv import load_dotenv
import google.generativeai as genai
import firebase_admin
from firebase_admin import credentials, firestore

# Load .env
load_dotenv()

# Configure Gemini API
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

# Initialize Flask
app = Flask(__name__)
CORS(app)

# Initialize Firebase
cred = credentials.Certificate(os.getenv("FIREBASE_CREDENTIALS"))  # serviceAccountKey.json
firebase_admin.initialize_app(cred)
db = firestore.client()


@app.route("/chat", methods=["POST"])
def chat():
    data = request.json
    user_message = data.get("message", "")

    if not user_message:
        return jsonify({"error": "Message is required"}), 400

    try:
        # Use Gemini model
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(user_message)
        bot_reply = response.text

        # Save conversation to Firestore
        db.collection("chats").add({
            "user_message": user_message,
            "bot_reply": bot_reply
        })

        return jsonify({"reply": bot_reply})

    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

from flask import Flask, request, send_file, jsonify
from flask_cors import CORS
import os
import uuid
import requests
import io
import time
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app)

# 🔑 Read API key securely from .env
CLOUDCONVERT_API_KEY = os.getenv("CLOUDCONVERT_API_KEY")

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


@app.route("/")
def home():
    return "Winzaap Converter API is running"


@app.route("/convert", methods=["POST"])
def convert():
    if "file" not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files["file"]
    filename = f"{uuid.uuid4()}_{file.filename}"
    input_path = os.path.join(UPLOAD_FOLDER, filename)
    file.save(input_path)

    headers = {
        "Authorization": f"Bearer {CLOUDCONVERT_API_KEY}",
        "Content-Type": "application/json"
    }

    try:
        # 1️⃣ Create CloudConvert job
        job_response = requests.post(
            "https://api.cloudconvert.com/v2/jobs",
            headers=headers,
            json={
                "tasks": {
                    "import-my-file": {
                        "operation": "import/upload"
                    },
                    "convert-my-file": {
                        "operation": "convert",
                        "input": "import-my-file",
                        "output_format": "pdf"
                    },
                    "export-my-file": {
                        "operation": "export/url",
                        "input": "convert-my-file"
                    }
                }
            }
        )

        job = job_response.json()["data"]
        upload_task = next(
            t for t in job["tasks"] if t["name"] == "import-my-file"
        )

        # 2️⃣ Upload file
        upload_url = upload_task["result"]["form"]["url"]
        form_data = upload_task["result"]["form"]["parameters"]

        with open(input_path, "rb") as f:
            files = {"file": f}
            requests.post(upload_url, data=form_data, files=files)

        # 3️⃣ Wait for conversion
        job_id = job["id"]
        while True:
            status_res = requests.get(
                f"https://api.cloudconvert.com/v2/jobs/{job_id}",
                headers=headers
            ).json()

            if status_res["data"]["status"] == "finished":
                break

            time.sleep(2)

        # 4️⃣ Download PDF
        export_task = next(
            t for t in status_res["data"]["tasks"]
            if t["name"] == "export-my-file"
        )

        file_url = export_task["result"]["files"][0]["url"]
        pdf_bytes = requests.get(file_url).content

        return send_file(
            io.BytesIO(pdf_bytes),
            as_attachment=True,
            download_name="converted.pdf",
            mimetype="application/pdf"
        )

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        if os.path.exists(input_path):
            os.remove(input_path)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
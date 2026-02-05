# Winzaap 📄✨

Winzaap is a mobile PDF utility app built using **Flutter** with a **Flask backend**.

## Features
- Image → PDF
- OCR (Text extraction)
- Word → PDF
- PPT → PDF

## Project Structure

winzaap/
├── flutter_app/   # Flutter mobile application
└── backend/       # Flask API (LibreOffice based converter)

## Backend
- Flask
- LibreOffice (headless)
- Converts DOC/DOCX/PPT/PPTX to PDF locally

## Frontend
- Flutter
- Firebase Authentication
- Saves PDFs inside app storage

## How to run backend locally

```bash
cd backend
source venv/bin/activate
python app.py

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
- Cloudconvert
- Converts DOC/DOCX/PPT/PPTX to PDF globally through Render

## Frontend
- Flutter
- Firebase Authentication
- Saves PDFs inside app storage

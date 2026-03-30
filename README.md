Here’s a clean, professional **README.md** you can use (polished, structured, and GitHub-ready):

---

# 📷 CCTV Stranger Detector

A real-time intelligent surveillance system that integrates embedded hardware, computer vision, and a Flutter-based mobile application to detect and alert users of unknown individuals.

---

## 🧠 Overview

The **CCTV Stranger Detector** is a smart security system built using a **Raspberry Pi 4 Model B** and a camera module for real-time face detection and recognition.

The system captures live video frames and processes them using **Python** and **OpenCV** to classify faces as **known** or **unknown** based on a trained dataset.

When an unrecognized (stranger) face is detected:

* 🚨 An alert is triggered instantly
* 📲 A notification is sent to the mobile application
* 🗂️ The detection event is logged for future reference

The accompanying **Flutter mobile app** allows users to monitor live feeds, receive alerts, and manage detection logs remotely.

---

## ⚙️ Tech Stack

### 🔌 Hardware

* Raspberry Pi 4 Model B
* Raspberry Pi Camera Module

### 🧠 Backend / Processing

* Python
* OpenCV
* Real-time video frame processing

### 📱 Mobile Application

* Flutter (Cross-platform: Android & iOS)
* Real-time alert notifications

---

## 🚀 Features

* 🎥 Real-time face detection
* 🧑‍🤝‍🧑 Known vs unknown face classification
* 🚨 Automated stranger alert system
* 📱 Live CCTV monitoring via mobile app
* 🌐 Remote access and monitoring
* 🗃️ Detection event logging

---

## 🏗️ System Architecture

```
Camera Module → Raspberry Pi → Face Detection (OpenCV)
                    ↓
          Face Recognition Model
                    ↓
        Known / Unknown Classification
                    ↓
     REST API → Flutter Mobile App
                    ↓
      Alerts + Logs + Live Monitoring
```

---

## 🎯 Objective

To design and develop a **cost-effective, scalable, and intelligent security solution** by integrating:

* IoT (Raspberry Pi)
* Computer Vision (Face Detection & Recognition)
* Mobile Development (Flutter)

into a unified real-time surveillance system.

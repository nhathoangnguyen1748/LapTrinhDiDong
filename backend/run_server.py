import os
import uvicorn

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    print("==========================================================")
    print(" LocalQuiz BLE & Cloud Sync - FastAPI Backend Starting")
    print(f" Listening on http://0.0.0.0:{port}")
    print(f" Swagger Documentation: http://localhost:{port}/docs")
    print("==========================================================")
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)

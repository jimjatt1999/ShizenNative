import sys
import whisper
import json

def log(message):
    """Print log messages to stderr"""
    print(message, file=sys.stderr, flush=True)

def transcribe_audio(audio_path):
    try:
        log("Loading Whisper model (base)...")
        model = whisper.load_model("base")
        
        log("Starting transcription...")
        result = model.transcribe(
            audio_path,
            verbose=False,
            language="ja"
        )
        
        # Process segments
        segments = []
        for segment in result["segments"]:
            processed_segment = {
                "text": segment["text"].strip(),
                "start": segment["start"],
                "end": segment["end"]
            }
            log(f"Processed segment: {processed_segment['text'][:30]}...")
            segments.append(processed_segment)
        
        log("Transcription complete!")
        
        # Print only the JSON data to stdout
        print(json.dumps(segments, ensure_ascii=False))
        sys.stdout.flush()
        
    except Exception as e:
        log(f"Error during transcription: {str(e)}")
        print(json.dumps({"error": str(e)}))
        sys.stdout.flush()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(json.dumps({"error": "Please provide an audio file path"}))
        sys.exit(1)
    else:
        transcribe_audio(sys.argv[1])

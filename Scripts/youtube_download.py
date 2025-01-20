import sys
import json
import yt_dlp

def download_audio(url):
    try:
        # Configure yt-dlp options
        ydl_opts = {
            'format': 'bestaudio/best',
            'postprocessors': [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '192',
            }],
            'outtmpl': '%(id)s.%(ext)s',
            'quiet': False,
            'no_warnings': False
        }

        # Download the video
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            print("Starting download...")
            info = ydl.extract_info(url, download=True)
            video_id = info['id']
            output_path = f"{video_id}.mp3"
            
            result = {
                'success': True,
                'path': output_path,
                'title': info.get('title', ''),
                'duration': info.get('duration', 0)
            }
            print(json.dumps(result))
            sys.stdout.flush()

    except Exception as e:
        error_result = {
            'success': False,
            'error': str(e)
        }
        print(json.dumps(error_result), file=sys.stderr)
        sys.stdout.flush()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(json.dumps({'success': False, 'error': 'URL required'}))
        sys.exit(1)
    
    download_audio(sys.argv[1])

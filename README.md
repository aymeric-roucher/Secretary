# Jarvis - macOS AI Secretary

A native macOS secretary app integrated with Gemini 1.5 Flash for multimodal understanding and Cerebras for reasoning.

## Original Prompt

I want to make a secretary app for mac. Basically an app that opens on a shortcut, Like Wispr Flow. It should have a top menu like this one: +------------------------------------------------------+
| Home |
| Check for updates... |
| Paste last transcript |
| Like Wispr Flow. |
| |
| Shortcuts |
| Microphone ▶ |
| Languages ▶ |
| |
| Help Center |
| Talk to support |
| General feedback |
| |
| Quit Wispr Flow |
+------------------------------------------------------+

Submenu: Microphone
+--------------------------------------+
| Auto-detect (AirPods) |
| AirPods |
| ✓ Built-in mic (recommended) |
+--------------------------------------+

Also, like wispr flow, it should display at all times a small semi-transparent cartridge at the bottom that grows up when pressed with a soundwave animation (all bars low) that ativates when hearing speech in the input. The way it would work behind the hodd is as follows : 
1 - Transcribe as soon as button is unpressed. Use this (btw you'll need to let users provide API keys, make a section for this in the Settings)
AUDIO_PATH="path/to/sample.mp3"
MIME_TYPE=$(file -b --mime-type "${AUDIO_PATH}")
NUM_BYTES=$(wc -c < "${AUDIO_PATH}")
DISPLAY_NAME=AUDIO

tmp_header_file=upload-header.tmp

# Initial resumable request defining metadata.
# The upload url is in the response headers dump them to a file.
curl "https://generativelanguage.googleapis.com/upload/v1beta/files" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -D upload-header.tmp \
  -H "X-Goog-Upload-Protocol: resumable" \
  -H "X-Goog-Upload-Command: start" \
  -H "X-Goog-Upload-Header-Content-Length: ${NUM_BYTES}" \
  -H "X-Goog-Upload-Header-Content-Type: ${MIME_TYPE}" \
  -H "Content-Type: application/json" \
  -d "{'file': {'display_name': '${DISPLAY_NAME}'}}" 2> /dev/null

upload_url=$(grep -i "x-goog-upload-url: " "${tmp_header_file}" | cut -d" " -f2 | tr -d "\r")
rm "${tmp_header_file}"

# Upload the actual bytes.
curl "${upload_url}" \
  -H "Content-Length: ${NUM_BYTES}" \
  -H "X-Goog-Upload-Offset: 0" \
  -H "X-Goog-Upload-Command: upload, finalize" \
  --data-binary "@${AUDIO_PATH}" 2> /dev/null > file_info.json

file_uri=$(jq ".file.uri" file_info.json)
echo file_uri=$file_uri

# Now generate content using that file
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
    -H "x-goog-api-key: $GEMINI_API_KEY" \
    -H 'Content-Type: application/json' \
    -X POST \
    -d '{ 
      "contents": [{ 
        "parts":[
          {"text": "Describe this audio clip"},
          {"file_data":{"mime_type": "${MIME_TYPE}", "file_uri": '$file_uri'}}] 
        }] 
      }' 2> /dev/null > response.json

cat response.json
echo

jq ".candidates[].content.parts[].text" response.json

2-Transcribe into tool calls.
Make a call to this cerebras model via hugging face (also need to provide an API token):
import os
import requests

API_URL = "https://router.huggingface.co/v1/chat/completions"
headers = {
    "Authorization": f"Bearer {os.environ['HF_TOKEN']}",
}

def query(payload):
    response = requests.post(API_URL, headers=headers, json=payload)
    return response.json()

response = query({
    "messages": [
        {
            "role": "user",
            "content": "What is the capital of France?"
        }
    ],
    "model": "Qwen/Qwen3-235B-A22B-Instruct-2507:cerebras"
})

print(response["choices"][0]["message"])
That model should be promptd to give a structured output with keys "reasoning", "tool_name", "tool_arguments", with the following set of toole: type (to just type in the currently selected textarea), open_app (to open a specific app by name, can be used to open browser at the given url or google search), deep_research (if the user asks to perform deep research on a speccific topic), switch_to (swtich the app displays do show another app by name amongg all open apps, this could be the equivalent of the Windows Alt+Tab).

So of course the app should have a setup upon first launch that has these pages: asking for authorizations (showing how to do this, with screenshots showing how to activate in mac settings), choosing languages (multi-select, users can have several languages), and at the end a button like "Let's go" to close it. The app should also be able to be open later on, this time showing different configuration tabs in one column to the left: Home (with logs of transcription and a dashboard with the count of words spoken), Dictionnary (to provide common abbreviations or snippets to transcribe in a certain way), Style (to provide some examples of emails, etc for style reference), and at the bottom left a Settings gear button.
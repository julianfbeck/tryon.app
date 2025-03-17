#!/bin/bash

# Script to test Gemini API with curl directly

# Load API key from .dev.vars or set it manually here
API_KEY=$(grep GOOGLE_API_KEY .dev.vars | cut -d= -f2)

# Check if API key is available
if [ -z "$API_KEY" ]; then
  echo "Error: No API key found. Please add it to .dev.vars or set it manually in this script."
  exit 1
fi

# Output file for the response
OUTPUT_FILE="gemini_response.out"
IMAGE_FILE="gemini_response.png"

# Create the request JSON
# Note: We're not including responseModalities based on previous errors
REQUEST_JSON=$(cat << EOF
{
  "contents": [
    {
      "parts": [
        {
          "fileData": {
            "fileUri": "https://generativelanguage.googleapis.com/v1beta/files/f3vroya4ibp4",
            "mimeType": "image/webp"
          }
        },
        {
          "text": "Here is a picture of my space"
        }
      ],
      "role": "user"
    },
    {
      "parts": [
        {
          "text": "Understood! I understand this is the space you are renovating and you want to visualize replacing some surfaces."
        }
      ],
      "role": "model"
    },
    {
      "parts": [
        {
          "text": "Here is a sample of a material I want to replace the Countertop with."
        },
        {
          "fileData": {
            "fileUri": "https://generativelanguage.googleapis.com/v1beta/files/dgi0teghgs7n",
            "mimeType": "image/jpeg"
          }
        }
      ],
      "role": "user"
    },
    {
      "parts": [
        {
          "text": "Got it! I see you want to replace the Countertop with this material."
        }
      ],
      "role": "model"
    },
    {
      "parts": [
        {
          "text": "Edit the image of my space (the first image I uploaded) by replacing the existing Countertop(s) with the material sample I selected (the second image uploaded). Isolate the Countertop(s) in the first image of my space and replace them and ONLY them with the material sample I provided. Try to minimize how much of the image of my space you change."
        }
      ],
      "role": "user"
    }
  ],
  "generationConfig": {
    "temperature": 0.5,
    "topP": 0.5,
    "topK": 40,
    "maxOutputTokens": 8192,
    "responseMimeType": "image/png",
	"responseModalities":["Text","Image"]
	}
  }
}
EOF
)

echo "Sending request to Gemini API..."
echo "API URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp-image-generation:generateContent"

# Using curl to send the request
RESPONSE=$(curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp-image-generation:generateContent?key=$API_KEY" \
  -H "Content-Type: application/json" \
  --data "$REQUEST_JSON" \
  --output "$OUTPUT_FILE" \
  -w "%{content_type}\n%{http_code}")

# Extract content type and status code from the response
CONTENT_TYPE=$(echo "$RESPONSE" | head -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)

echo "Response received with HTTP code: $HTTP_CODE"
echo "Content type: $CONTENT_TYPE"

# Check if the response was successful
if [[ $HTTP_CODE == 2* ]]; then
  echo "Request successful!"
  
  # If the response is an image
  if [[ $CONTENT_TYPE == *"image"* ]]; then
    echo "Received image response, saved to $OUTPUT_FILE"
    # Rename to appropriate extension
    mv "$OUTPUT_FILE" "$IMAGE_FILE"
    echo "Renamed to $IMAGE_FILE"
  else
    # Display the text response
    echo "Response content:"
    cat "$OUTPUT_FILE"
  fi
else
  echo "Request failed with status code: $HTTP_CODE"
  echo "Error response:"
  cat "$OUTPUT_FILE"
fi

# Version with responseModalities for comparison (will likely fail)
echo -e "\n\nTesting with responseModalities (may fail)..."

REQUEST_JSON_WITH_MODALITIES=$(cat << EOF
{
  "contents": [
    {
      "parts": [
        {
          "fileData": {
            "fileUri": "https://generativelanguage.googleapis.com/v1beta/files/f3vroya4ibp4",
            "mimeType": "image/webp"
          }
        },
        {
          "text": "Here is a picture of my space"
        }
      ],
      "role": "user"
    },
    {
      "parts": [
        {
          "text": "Understood! I understand this is the space you are renovating and you want to visualize replacing some surfaces."
        }
      ],
      "role": "model"
    },
    {
      "parts": [
        {
          "text": "Here is a sample of a material I want to replace the Countertop with."
        },
        {
          "fileData": {
            "fileUri": "https://generativelanguage.googleapis.com/v1beta/files/dgi0teghgs7n",
            "mimeType": "image/jpeg"
          }
        }
      ],
      "role": "user"
    },
    {
      "parts": [
        {
          "text": "Got it! I see you want to replace the Countertop with this material."
        }
      ],
      "role": "model"
    },
    {
      "parts": [
        {
          "text": "Edit the image of my space (the first image I uploaded) by replacing the existing Countertop(s) with the material sample I selected (the second image uploaded). Isolate the Countertop(s) in the first image of my space and replace them and ONLY them with the material sample I provided. Try to minimize how much of the image of my space you change."
        }
      ],
      "role": "user"
    }
  ],
  "generationConfig": {
    "temperature": 0.5,
    "topP": 0.5,
    "topK": 40,
    "maxOutputTokens": 8192,
    "responseMimeType": "text/plain"
  },
  "responseModalities": [
    "image",
    "text"
  ]
}
EOF
)

# Using curl to send the request with responseModalities
RESPONSE_WITH_MODALITIES=$(curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp-image-generation:generateContent?key=$API_KEY" \
  -H "Content-Type: application/json" \
  --data "$REQUEST_JSON_WITH_MODALITIES" \
  --output "gemini_response_with_modalities.out" \
  -w "%{content_type}\n%{http_code}")

# Extract content type and status code from the response
CONTENT_TYPE_WITH_MODALITIES=$(echo "$RESPONSE_WITH_MODALITIES" | head -1)
HTTP_CODE_WITH_MODALITIES=$(echo "$RESPONSE_WITH_MODALITIES" | tail -1)

echo "Response received with HTTP code: $HTTP_CODE_WITH_MODALITIES"
echo "Content type: $CONTENT_TYPE_WITH_MODALITIES"

# Check if the response was successful
if [[ $HTTP_CODE_WITH_MODALITIES == 2* ]]; then
  echo "Request with responseModalities was successful!"
  
  # Display the response
  echo "Response content:"
  cat "gemini_response_with_modalities.out"
else
  echo "Request with responseModalities failed with status code: $HTTP_CODE_WITH_MODALITIES"
  echo "Error response:"
  cat "gemini_response_with_modalities.out"
fi 
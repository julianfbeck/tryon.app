import { Hono } from 'hono'
import { serveStatic } from 'hono/cloudflare-workers'

interface Env {
  GOOGLE_API_KEY: string;
}

interface ImageData {
  data: string;
  mime_type: string;
}

interface RequestBody {
  person: ImageData;
  clothing: ImageData;
}

interface GeminiResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{
        inlineData?: {
          data: string;
        };
      }>;
    };
  }>;
  promptFeedback?: any;
}

const app = new Hono<{ Bindings: Env }>()

app.use('/static/*', serveStatic({ root: './', manifest: {} }))

// Serve the frontend
app.get('/', async (c) => {
  return c.html(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Virtual Try-On</title>
        <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-gray-100 min-h-screen p-8">
        <div class="max-w-4xl mx-auto">
            <h1 class="text-3xl font-bold mb-8 text-center">Virtual Try-On</h1>
            
            <div class="bg-white p-6 rounded-lg shadow-md">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <!-- Person Image Upload -->
                    <div class="space-y-4">
                        <h2 class="text-xl font-semibold">Your Photo</h2>
                        <div class="border-2 border-dashed border-gray-300 rounded-lg p-4">
                            <input type="file" id="personImage" accept="image/*" class="hidden">
                            <label for="personImage" class="cursor-pointer block">
                                <div id="personPreview" class="aspect-square bg-gray-50 flex items-center justify-center">
                                    <span class="text-gray-500">Click to upload your photo</span>
                                </div>
                            </label>
                        </div>
                    </div>

                    <!-- Clothing Image Upload -->
                    <div class="space-y-4">
                        <h2 class="text-xl font-semibold">Clothing Item</h2>
                        <div class="border-2 border-dashed border-gray-300 rounded-lg p-4">
                            <input type="file" id="clothingImage" accept="image/*" class="hidden">
                            <label for="clothingImage" class="cursor-pointer block">
                                <div id="clothingPreview" class="aspect-square bg-gray-50 flex items-center justify-center">
                                    <span class="text-gray-500">Click to upload clothing</span>
                                </div>
                            </label>
                        </div>
                    </div>
                </div>

                <!-- Try On Button -->
                <div class="mt-6 text-center">
                    <button id="tryOnButton" class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50" disabled>
                        Try On
                    </button>
                </div>

                <!-- Result Section -->
                <div id="resultSection" class="mt-8 hidden">
                    <h2 class="text-xl font-semibold mb-4">Result</h2>
                    <div id="resultImage" class="aspect-square bg-gray-50 flex items-center justify-center rounded-lg"></div>
                </div>
            </div>
        </div>

        <script>
            let personFile = null;
            let clothingFile = null;

            function updateButtonState() {
                const button = document.getElementById('tryOnButton');
                button.disabled = !personFile || !clothingFile;
            }

            function setupImageUpload(inputId, previewId, setter) {
                const input = document.getElementById(inputId);
                const preview = document.getElementById(previewId);

                input.addEventListener('change', (e) => {
                    const file = e.target.files[0];
                    if (file) {
                        setter(file);
                        const reader = new FileReader();
                        reader.onload = (e) => {
                            preview.innerHTML = \`<img src="\${e.target.result}" class="max-w-full max-h-full object-contain">\`;
                        };
                        reader.readAsDataURL(file);
                        updateButtonState();
                    }
                });
            }

            setupImageUpload('personImage', 'personPreview', (file) => personFile = file);
            setupImageUpload('clothingImage', 'clothingPreview', (file) => clothingFile = file);

            document.getElementById('tryOnButton').addEventListener('click', async () => {
                if (!personFile || !clothingFile) return;

                const formData = new FormData();
                formData.append('person', personFile);
                formData.append('clothing', clothingFile);

                try {
                    const response = await fetch('/api/tryon', {
                        method: 'POST',
                        body: formData
                    });

                    if (!response.ok) throw new Error('Failed to process images');

                    const result = await response.blob();
                    const resultUrl = URL.createObjectURL(result);
                    
                    document.getElementById('resultSection').classList.remove('hidden');
                    document.getElementById('resultImage').innerHTML = \`
                        <img src="\${resultUrl}" class="max-w-full max-h-full object-contain">
                    \`;
                } catch (error) {
                    alert('Error: ' + error.message);
                }
            });
        </script>
    </body>
    </html>
  `)
})

// API endpoint for try-on
app.post('/api/tryon', async (c) => {
  try {
    const body = await c.req.json<RequestBody>()
    const { person, clothing } = body

    if (!person?.data || !clothing?.data) {
      console.error('Missing required images:', {
        hasPerson: !!person?.data,
        hasClothing: !!clothing?.data
      })
      throw new Error('Both person and clothing images are required')
    }

    console.log('Processing images:', {
      personType: person.mime_type,
      personDataLength: person.data.length,
      clothingType: clothing.mime_type,
      clothingDataLength: clothing.data.length
    })

    // Prepare the request for Gemini API
    const requestBody = {
      contents: [{
        role: "user",
        parts: [

          {
            inline_data: {
              mime_type: person.mime_type,
              data: person.data
            }
          },
          {
            inline_data: {
              mime_type: clothing.mime_type,
              data: clothing.data
            }
          },
          {
            text: "Let the person wear the clothing. Same Pose"
          }
        ]
      }
        // ,
        // {
        //   role: "user",
        //   parts: [
        //     {
        //       text: "Please generate an image of me wearing this clothing item, maintaining my pose and appearance while naturally integrating the clothing."
        //     }
        //   ]
        // }
      ],
      generationConfig: {
        temperature: 1,
        topP: 0.95,
        topK: 40,
        maxOutputTokens: 8192,
        responseModalities: ["Text", "Image"]
      }
    }

    const apiKey = c.env?.GOOGLE_API_KEY
    if (!apiKey) {
      throw new Error('API key not configured')
    }


    const apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp-image-generation:generateContent?key=' + apiKey

    const response = await fetch(
      apiUrl,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody)
      }
    )

    if (!response.ok) {
      const errorText = await response.text()
      console.error('Gemini API error:', {
        status: response.status,
        statusText: response.statusText,
        error: errorText
      })
      throw new Error(`Failed to generate image: ${response.status} ${response.statusText}`)
    }

    console.log('Successfully received response from Gemini API')
    const data = await response.json()
    const responseData = data as GeminiResponse
    console.log('Parsed API Response:', {
      candidates: responseData.candidates,
      promptFeedback: responseData.promptFeedback
    })

    // Check if we have image data in the response
    if (responseData.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data) {
      const base64Image = responseData.candidates[0].content.parts[0].inlineData.data
      const binaryData = atob(base64Image)
      const uint8Array = new Uint8Array(binaryData.length)
      for (let i = 0; i < binaryData.length; i++) {
        uint8Array[i] = binaryData.charCodeAt(i)
      }

      const blob = new Blob([uint8Array], { type: 'image/png' })
      console.log('Created image blob:', {
        size: blob.size,
        type: blob.type
      })

      return new Response(blob, {
        headers: { 'Content-Type': 'image/png' }
      })
    } else {
      console.error('No image data found in response')
      throw new Error('No image data in response')
    }
  } catch (error: any) {
    console.error('Error in /api/tryon:', {
      message: error?.message,
      stack: error?.stack,
      cause: error?.cause
    })
    return c.json({
      error: error?.message || 'Unknown error',
      details: error?.stack
    }, 500)
  }
})

export default app
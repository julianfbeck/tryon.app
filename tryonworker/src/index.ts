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
  imageCount?: number;
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

// API endpoint for try-on
app.post('/api/tryon', async (c) => {
  try {
    const body = await c.req.json<RequestBody>()
    const { person, clothing, imageCount = 1 } = body

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
      clothingDataLength: clothing.data.length,
      requestedImageCount: imageCount || 1
    })

    const apiKey = c.env?.GOOGLE_API_KEY
    if (!apiKey) {
      throw new Error('API key not configured')
    }

    // Function to make a single API request
    const makeRequest = async () => {
      // Use the original request body structure
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
              text: "Make the person in the first image wear the clothing in the second image"
            }
          ]
        }],
        generationConfig: {
          temperature: 0.95,
          topP: 0.95,
          topK: 40,
          maxOutputTokens: 8192,
          responseModalities: ["Text", "Image"]
        }
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

      const data = await response.json()
      const responseData = data as GeminiResponse

      // Extract the image data
      if (responseData.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data) {
        return responseData.candidates[0].content.parts[0].inlineData.data
      } else {
        throw new Error('This didn\'t work. Try using a a clear image of the person and a clear image of the clothing. Sorry!')
      }
    }

    // Create an array of promises for the requested number of images
    const requestCount = Math.min(Math.max(1, imageCount), 4) // Limit to between 1 and 4 images
    const requests = Array(requestCount).fill(0).map(() => makeRequest())

    // Execute all requests in parallel
    const imageResults = await Promise.all(requests)
    console.log(`Successfully generated ${imageResults.length} images`)

    // If only one image was requested, return it directly as before
    if (imageResults.length === 1) {
      const base64Image = imageResults[0]
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
    }
    // For multiple images, create a JSON response with an array of base64 encoded images
    else {
      return c.json({
        images: imageResults
      })
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
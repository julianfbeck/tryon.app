import { Hono } from 'hono'
import geminiRouter from './api/gemini'
import geminiImageRouter from './api/gemini-image'

// Define environment interface
interface Env {
  GOOGLE_API_KEY: string;
}

// Define interface for image generation requests
interface GeminiImageRequest {
  contents: Array<{
    role?: string;
    parts: Array<{
      text?: string;
    } | {
      inline_data: {
        mime_type: string;
        data: string;
      }
    }>
  }>;
  generationConfig?: {
    temperature?: number;
    topP?: number;
    topK?: number;
    maxOutputTokens?: number;
    responseMimeType?: string;
  };
  responseModalities?: string[]; // This won't be used in API calls
}

const app = new Hono<{ Bindings: Env }>()

app.get('/', (c) => {
  return c.text('Hello Hono!')
})

// Mount the Gemini API endpoints
app.route('/api/gemini', geminiRouter)
app.route('/api/gemini-image', geminiImageRouter)

// Debug route for direct testing
app.post('/api/debug-image', async (c) => {
  const apiKey = c.env.GOOGLE_API_KEY;

  if (!apiKey) {
    return new Response(JSON.stringify({ error: 'API key not configured' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  try {
    // Log the request body for debugging
    const requestBody = await c.req.json() as GeminiImageRequest;

    // Create a sanitized version of the request data
    const sanitizedRequestData = {
      contents: requestBody.contents,
      generationConfig: requestBody.generationConfig || {}
    };

    // Ensure generationConfig contains responseMimeType
    if (!sanitizedRequestData.generationConfig.responseMimeType) {
      sanitizedRequestData.generationConfig.responseMimeType = "image/png";
    }

    console.log('Debug - Request body:', JSON.stringify(sanitizedRequestData));

    // Forward the request to Google API
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp-image-generation:generateContent?key=${apiKey}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(sanitizedRequestData)
    });

    console.log('Debug - Status code:', response.status);
    console.log('Debug - Status text:', response.statusText);

    // Log all response headers
    const headerObj: Record<string, string> = {};
    response.headers.forEach((value, key) => {
      headerObj[key] = value;
    });
    console.log('Debug - Response headers:', JSON.stringify(headerObj));

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Debug - Error response:', errorText);
      try {
        const errorJson = JSON.parse(errorText);
        return new Response(JSON.stringify({ error: 'API Error', details: errorJson }), {
          status: response.status,
          headers: { 'Content-Type': 'application/json' }
        });
      } catch (e) {
        return new Response(JSON.stringify({ error: 'API Error', rawResponse: errorText }), {
          status: response.status,
          headers: { 'Content-Type': 'application/json' }
        });
      }
    }

    // Check content type
    const contentType = response.headers.get('content-type');
    console.log('Debug - Content-Type:', contentType);

    if (contentType && contentType.includes('image')) {
      const imageBuffer = await response.arrayBuffer();
      return new Response(imageBuffer, {
        headers: { 'Content-Type': contentType }
      });
    }

    // Return JSON response
    const data = await response.json();
    return new Response(JSON.stringify(data), {
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    console.error('Debug - Error:', error);
    return new Response(JSON.stringify({ error: 'Debug API error', message: String(error) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
});

// Inline the test client HTML content
app.get('/test', (c) => {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gemini API Test Client</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
        }
        textarea {
            width: 100%;
            height: 100px;
            margin-bottom: 10px;
            padding: 8px;
            border-radius: 4px;
            border: 1px solid #ccc;
        }
        button {
            background-color: #4CAF50;
            color: white;
            padding: 10px 15px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background-color: #45a049;
        }
        pre {
            background-color: #f5f5f5;
            padding: 15px;
            border-radius: 4px;
            overflow-x: auto;
            max-height: 500px;
            border: 1px solid #ddd;
        }
        .response-container {
            margin-top: 20px;
        }
        .tabs {
            display: flex;
            margin-bottom: 20px;
            border-bottom: 1px solid #ddd;
        }
        .tab {
            padding: 10px 15px;
            cursor: pointer;
            border: 1px solid transparent;
            border-bottom: none;
            border-radius: 4px 4px 0 0;
            margin-right: 5px;
        }
        .tab.active {
            background-color: #f5f5f5;
            border-color: #ddd;
            border-bottom-color: #f5f5f5;
        }
        .tab-content {
            display: none;
        }
        .tab-content.active {
            display: block;
        }
        .file-input-container {
            margin-bottom: 15px;
        }
        .preview-container {
            margin: 15px 0;
            max-width: 100%;
        }
        .preview-container img {
            max-width: 100%;
            max-height: 300px;
            border: 1px solid #ddd;
            border-radius: 4px;
        }
        .no-image {
            display: flex;
            align-items: center;
            justify-content: center;
            height: 150px;
            border: 1px dashed #ccc;
            border-radius: 4px;
            color: #999;
        }
        .debug-checkbox {
            margin-top: 10px;
            margin-bottom: 10px;
        }
        .json-editor {
            width: 100%;
            height: 200px;
            font-family: monospace;
            margin-top: 10px;
            margin-bottom: 10px;
            padding: 8px;
        }
    </style>
</head>
<body>
    <h1>Gemini API Test Client</h1>
    
    <div class="tabs">
        <div class="tab active" data-tab="text">Text Generation</div>
        <div class="tab" data-tab="image">Image Generation</div>
    </div>

    <div id="text-tab" class="tab-content active">
        <h2>Enter your prompt:</h2>
        <textarea id="prompt" placeholder="Enter your prompt here...">Explain how AI works</textarea>
        
        <button onclick="callGeminiAPI()">Submit</button>
        
        <div class="response-container">
            <h2>Response:</h2>
            <pre id="response">Response will appear here...</pre>
        </div>
    </div>

    <div id="image-tab" class="tab-content">
        <h2>Image Generation</h2>
        
        <div class="file-input-container">
            <label for="image-upload">Upload an image:</label>
            <input type="file" id="image-upload" accept="image/*" onchange="handleImageUpload(event)">
        </div>
        
        <div class="preview-container">
            <div id="image-preview" class="no-image">No image selected</div>
        </div>
        
        <h3>Enter your prompt:</h3>
        <textarea id="image-prompt" placeholder="Describe how to modify the image...">change elephant to a bulldozer</textarea>
        
        <div style="margin-top: 10px;">
            <label for="temperature">Temperature:</label>
            <input type="range" id="temperature" min="0" max="1" step="0.1" value="1">
            <span id="temperature-value">1</span>
        </div>
        
        <div class="debug-checkbox">
            <label>
                <input type="checkbox" id="debug-mode" onchange="toggleDebugMode()"> 
                Debug Mode (Direct API access)
            </label>
        </div>
        
        <div id="debug-container" style="display: none;">
            <h4>API Request JSON:</h4>
            <textarea id="debug-json" class="json-editor"></textarea>
        </div>
        
        <button onclick="callGeminiImageAPI()" style="margin-top: 10px;">Generate Image</button>
        
        <div class="response-container">
            <h2>Generated Image:</h2>
            <div id="image-response">
                <div class="no-image">Generated image will appear here</div>
            </div>
            <pre id="image-error" style="display: none;">Error will appear here...</pre>
        </div>
    </div>

    <script>
        // Tab switching
        document.querySelectorAll('.tab').forEach(tab => {
            tab.addEventListener('click', () => {
                document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
                document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
                
                tab.classList.add('active');
                document.getElementById(tab.dataset.tab + '-tab').classList.add('active');
            });
        });
        
        // Range slider update
        document.getElementById('temperature').addEventListener('input', function() {
            document.getElementById('temperature-value').textContent = this.value;
        });
        
        // Text API
        async function callGeminiAPI() {
            const promptText = document.getElementById('prompt').value;
            const responseElement = document.getElementById('response');
            
            responseElement.textContent = 'Loading...';
            
            try {
                const response = await fetch('/api/gemini', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        contents: [{
                            parts: [{ text: promptText }]
                        }]
                    })
                });
                
                const data = await response.json();
                responseElement.textContent = JSON.stringify(data, null, 2);
            } catch (error) {
                responseElement.textContent = \`Error: \${error.message}\`;
            }
        }
        
        // Image handling
        let imageBase64 = null;
        let imageType = null;
        
        function handleImageUpload(event) {
            const file = event.target.files[0];
            if (!file) return;
            
            const reader = new FileReader();
            reader.onload = function(e) {
                const result = e.target.result;
                imageBase64 = result.split(',')[1]; // Remove the data URL prefix
                imageType = file.type;
                
                const preview = document.getElementById('image-preview');
                preview.innerHTML = '';
                preview.classList.remove('no-image');
                
                const img = document.createElement('img');
                img.src = result;
                preview.appendChild(img);
                
                // Update debug JSON if in debug mode
                if (document.getElementById('debug-mode').checked) {
                    updateDebugJson();
                }
            };
            reader.readAsDataURL(file);
        }
        
        function toggleDebugMode() {
            const debugContainer = document.getElementById('debug-container');
            const isDebugMode = document.getElementById('debug-mode').checked;
            
            debugContainer.style.display = isDebugMode ? 'block' : 'none';
            
            if (isDebugMode) {
                updateDebugJson();
            }
        }
        
        function updateDebugJson() {
            if (!imageBase64) return;
            
            const promptText = document.getElementById('image-prompt').value;
            const temperature = parseFloat(document.getElementById('temperature').value);
            
            const requestObj = {
                contents: [{
                    role: "user",
                    parts: [
                        {
                            inline_data: {
                                mime_type: imageType,
                                data: imageBase64
                            }
                        },
                        {
                            text: promptText
                        }
                    ]
                }],
                generationConfig: {
                    temperature: temperature,
                    topP: 0.95,
                    topK: 40,
                    maxOutputTokens: 8192,
                    responseMimeType: "image/png"
                }
            };
            
            document.getElementById('debug-json').value = JSON.stringify(requestObj, null, 2);
        }
        
        // Image generation API
        async function callGeminiImageAPI() {
            if (!imageBase64) {
                alert('Please upload an image first.');
                return;
            }
            
            const isDebugMode = document.getElementById('debug-mode').checked;
            const imageResponseElement = document.getElementById('image-response');
            const errorElement = document.getElementById('image-error');
            
            imageResponseElement.innerHTML = '<div class="no-image">Loading...</div>';
            errorElement.style.display = 'none';
            
            try {
                let requestBody;
                
                if (isDebugMode) {
                    // Use the JSON from the debug editor
                    try {
                        requestBody = JSON.parse(document.getElementById('debug-json').value);
                    } catch (e) {
                        alert('Invalid JSON in the debug editor');
                        return;
                    }
                } else {
                    // Build the request body normally
                    const promptText = document.getElementById('image-prompt').value;
                    const temperature = parseFloat(document.getElementById('temperature').value);
                    
                    requestBody = {
                        contents: [{
                            role: "user",
                            parts: [
                                {
                                    inline_data: {
                                        mime_type: imageType,
                                        data: imageBase64
                                    }
                                },
                                {
                                    text: promptText
                                }
                            ]
                        }],
                        generationConfig: {
                            temperature: temperature,
                            topP: 0.95,
                            topK: 40,
                            maxOutputTokens: 8192,
                            responseMimeType: "image/png"
                        }
                    };
                }
                
                // Choose the endpoint based on debug mode
                const endpoint = isDebugMode ? '/api/debug-image' : '/api/gemini-image';
                
                const response = await fetch(endpoint, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(requestBody)
                });
                
                if (!response.ok) {
                    const errorData = await response.json();
                    throw new Error(JSON.stringify(errorData, null, 2));
                }
                
                const contentType = response.headers.get('content-type');
                
                if (contentType && contentType.includes('image')) {
                    // Handle image response
                    const blob = await response.blob();
                    const imageUrl = URL.createObjectURL(blob);
                    
                    imageResponseElement.innerHTML = '';
                    const img = document.createElement('img');
                    img.src = imageUrl;
                    imageResponseElement.appendChild(img);
                } else {
                    // Handle JSON response
                    const data = await response.json();
                    errorElement.textContent = JSON.stringify(data, null, 2);
                    errorElement.style.display = 'block';
                    imageResponseElement.innerHTML = '<div class="no-image">No image generated</div>';
                }
            } catch (error) {
                errorElement.textContent = \`Error: \${error.message}\`;
                errorElement.style.display = 'block';
                imageResponseElement.innerHTML = '<div class="no-image">Failed to generate image</div>';
            }
        }
    </script>
</body>
</html>`;
  return c.html(html);
})

export default app

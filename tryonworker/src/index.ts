import { Hono } from 'hono'
import geminiRouter from './api/gemini'

const app = new Hono()

app.get('/', (c) => {
  return c.text('Hello Hono!')
})

// Mount the Gemini API endpoint
app.route('/api/gemini', geminiRouter)

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
    </style>
</head>
<body>
    <h1>Gemini API Test Client</h1>
    
    <h2>Enter your prompt:</h2>
    <textarea id="prompt" placeholder="Enter your prompt here...">Explain how AI works</textarea>
    
    <button onclick="callGeminiAPI()">Submit</button>
    
    <div class="response-container">
        <h2>Response:</h2>
        <pre id="response">Response will appear here...</pre>
    </div>

    <script>
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
    </script>
</body>
</html>`;
  return c.html(html);
})

export default app

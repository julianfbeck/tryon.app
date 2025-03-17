import { Hono } from 'hono';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';

// Define the environment interface
interface Env {
	GOOGLE_API_KEY: string;
}

// Define the type for request data
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
	responseModalities?: string[]; // This won't be used in API calls but may be in incoming requests
}

const geminiImage = new Hono<{ Bindings: Env }>();

const requestSchema = z.object({
	contents: z.array(
		z.object({
			role: z.string().optional(),
			parts: z.array(
				z.union([
					z.object({
						text: z.string().optional()
					}),
					z.object({
						inline_data: z.object({
							mime_type: z.string(),
							data: z.string() // base64 encoded image
						})
					})
				])
			)
		})
	),
	generationConfig: z.object({
		temperature: z.number().optional(),
		topP: z.number().optional(),
		topK: z.number().optional(),
		maxOutputTokens: z.number().optional(),
		responseMimeType: z.string().optional()
	}).optional(),
	responseModalities: z.array(z.string()).optional() // Allow this in the validation but don't use it in API calls
});

const GEMINI_IMAGE_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp-image-generation:generateContent';

geminiImage.post('/', zValidator('json', requestSchema), async (c) => {
	const apiKey = c.env.GOOGLE_API_KEY;

	if (!apiKey) {
		return new Response(JSON.stringify({ error: 'API key not configured' }), {
			status: 500,
			headers: { 'Content-Type': 'application/json' }
		});
	}

	const requestData = c.req.valid('json') as GeminiImageRequest;

	// Create a sanitized version of the request data
	const sanitizedRequestData = {
		contents: requestData.contents,
		generationConfig: requestData.generationConfig || {}
	};

	// Ensure generationConfig contains responseMimeType
	if (!sanitizedRequestData.generationConfig.responseMimeType) {
		sanitizedRequestData.generationConfig.responseMimeType = "image/png";
	}

	console.log('Request data:', JSON.stringify(sanitizedRequestData));

	try {
		const response = await fetch(`${GEMINI_IMAGE_API_URL}?key=${apiKey}`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json'
			},
			body: JSON.stringify(sanitizedRequestData)
		});

		if (!response.ok) {
			const errorData = await response.json();
			console.error('Gemini API error:', JSON.stringify(errorData));
			return new Response(JSON.stringify({ error: 'Gemini API error', details: errorData }), {
				status: response.status,
				headers: { 'Content-Type': 'application/json' }
			});
		}

		// Check if the response is an image
		const contentType = response.headers.get('content-type');
		if (contentType && contentType.includes('image')) {
			// Return the image data directly
			const imageBuffer = await response.arrayBuffer();
			return new Response(imageBuffer, {
				headers: {
					'Content-Type': contentType
				}
			});
		}

		// Otherwise, return JSON
		const data = await response.json();
		return new Response(JSON.stringify(data), {
			headers: { 'Content-Type': 'application/json' }
		});
	} catch (error) {
		console.error('Error calling Gemini Image API:', error);
		return new Response(JSON.stringify({ error: 'Failed to call Gemini Image API', message: String(error) }), {
			status: 500,
			headers: { 'Content-Type': 'application/json' }
		});
	}
});

export default geminiImage; 
import { Hono } from 'hono';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';

const gemini = new Hono();

const requestSchema = z.object({
	contents: z.array(
		z.object({
			parts: z.array(
				z.object({
					text: z.string().min(1)
				})
			)
		})
	)
});

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

gemini.post('/', zValidator('json', requestSchema), async (c) => {
	const apiKey = c.env.GOOGLE_API_KEY;

	if (!apiKey) {
		return c.json({ error: 'API key not configured' }, 500);
	}

	const requestData = c.req.valid('json');

	try {
		const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json'
			},
			body: JSON.stringify(requestData)
		});

		if (!response.ok) {
			const errorData = await response.json();
			return c.json({ error: 'Gemini API error', details: errorData }, response.status);
		}

		const data = await response.json();
		return c.json(data);
	} catch (error) {
		console.error('Error calling Gemini API:', error);
		return c.json({ error: 'Failed to call Gemini API' }, 500);
	}
});

export default gemini; 
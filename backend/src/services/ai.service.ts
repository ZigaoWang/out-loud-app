import OpenAI from 'openai';
import { config } from '../../config';

interface AnalysisResult {
  summary: string;
  keywords: string[];
  feedback: string;
  report: {
    thinkingIntensity: number;
    pauseTime: number;
    coherenceScore: number;
    missingPoints: string[];
  };
  followUpQuestion: string;
}

interface InteractionSuggestion {
  shouldInterrupt: boolean;
  question?: string;
}

export class AIService {
  private openai: OpenAI;

  constructor() {
    this.openai = new OpenAI({
      apiKey: config.openai.apiKey,
      baseURL: config.openai.baseUrl,
    });
  }

  async analyzeSession(transcript: string, duration: number): Promise<AnalysisResult> {
    const prompt = `You are an expert learning coach. The user just completed a study session lasting ${duration.toFixed(1)} seconds. Here's what they explained:

"${transcript}"

Analyze this learning session and provide comprehensive, professional feedback in JSON format with these exact keys:

{
  "summary": "A concise 2-3 sentence summary of what the user explained and the main concepts covered",
  "keywords": ["3-5 key concepts or topics as an array of strings"],
  "feedback": "One encouraging sentence about their explanation quality, clarity, or depth of understanding",
  "report": {
    "thinkingIntensity": <number 0-100 based on depth of explanation, logical flow, and conceptual connections>,
    "pauseTime": <estimated seconds of hesitation or repetitive filler>,
    "coherenceScore": <number 0-100 based on logical structure and topic coherence>,
    "missingPoints": ["array of 2-4 specific aspects or details that could strengthen their explanation"]
  },
  "followUpQuestion": "One thought-provoking question to deepen understanding or explore a related concept"
}

Scoring guidelines:
- thinkingIntensity: 80-100 = exceptional depth, 60-79 = solid understanding, 40-59 = basic grasp, 20-39 = fragmented understanding, 0-19 = surface level
- coherenceScore: 80-100 = excellent flow, 60-79 = mostly coherent, 40-59 = somewhat scattered, 20-39 = highly fragmented with repetition, 0-19 = disjointed
- pauseTime: Estimate total seconds of pauses, filler words (um, uh), and repetitive phrases
- missingPoints should be specific and actionable (e.g., "Explain the underlying mechanism" not "Add more details")
- followUpQuestion should build on what they said, not repeat basic concepts

For feedback:
- If coherenceScore < 40 or transcript shows excessive repetition/fragmentation: Acknowledge the effort but suggest focusing on organizing thoughts before speaking
- If coherenceScore 40-79: Highlight strengths and provide constructive guidance
- If coherenceScore >= 80: Give strong encouragement and challenge them to go deeper

Be supportive yet honest. Focus on growth and deeper understanding.`;

    const response = await this.openai.chat.completions.create({
      model: config.openai.model,
      messages: [
        {
          role: 'system',
          content: 'You are an expert learning coach who provides insightful, constructive analysis of student explanations. You balance encouragement with honest assessment to foster growth and deeper understanding.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.7,
    });

    const result = JSON.parse(response.choices[0].message.content || '{}');

    // Ensure all fields have proper defaults
    return {
      summary: result.summary || 'Your learning session has been analyzed.',
      keywords: Array.isArray(result.keywords) ? result.keywords : [],
      feedback: result.feedback || 'Keep practicing to improve your explanations.',
      report: {
        thinkingIntensity: typeof result.report?.thinkingIntensity === 'number' ? result.report.thinkingIntensity : 50,
        pauseTime: typeof result.report?.pauseTime === 'number' ? result.report.pauseTime : 0,
        coherenceScore: typeof result.report?.coherenceScore === 'number' ? result.report.coherenceScore : 50,
        missingPoints: Array.isArray(result.report?.missingPoints) ? result.report.missingPoints : [],
      },
      followUpQuestion: result.followUpQuestion || 'What would you like to explore next?',
    };
  }

  async shouldInteractNow(
    currentTranscript: string,
    recentPauses: number[],
    context: string
  ): Promise<InteractionSuggestion> {
    const avgPause = recentPauses.reduce((a, b) => a + b, 0) / recentPauses.length;

    const prompt = `用户正在讲解学习内容。当前已说：

"${currentTranscript}"

上下文: ${context}
最近平均停顿: ${avgPause}秒

判断是否需要现在介入提问，以及提什么问题。如果用户：
- 停顿过久（可能卡住了）
- 表达模糊或跳跃
- 偏离主题
则建议介入。

回复JSON格式：
{
  "shouldInterrupt": true/false,
  "question": "如果需要介入，这里是问题"
}`;

    const response = await this.openai.chat.completions.create({
      model: config.openai.model,
      messages: [
        {
          role: 'system',
          content: '你是一个温和的学习助手，在用户需要帮助时适时提问，引导思考。',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.5,
    });

    const result = JSON.parse(response.choices[0].message.content || '{}');
    return {
      shouldInterrupt: result.shouldInterrupt || false,
      question: result.question,
    };
  }

  async generateRealtimeCaption(partialTranscript: string): Promise<string> {
    // Short, simple summaries - topic names only, no meta-language
    try {
      const response = await this.openai.chat.completions.create({
        model: config.openai.model,
        messages: [
          {
            role: 'system',
            content: 'Extract the main topic in 2-4 words. Output ONLY the topic, no verbs, no descriptions. For Chinese: output in Chinese. For English: output in English. For mixed: use the dominant language. Never say "talking about", "discussing", "explaining", "clarifying", "fragmented". Examples: "机器学习算法", "牛顿第二定律", "React Hooks", "数据库设计".',
          },
          {
            role: 'user',
            content: partialTranscript,
          },
        ],
        temperature: 0.2,
        max_tokens: 10,
      });

      return response.choices[0].message.content?.trim() || '';
    } catch (error) {
      console.error('Caption generation error:', error);
      return ''; // Fail silently, don't block the flow
    }
  }

  async generateSessionTitle(transcript: string): Promise<string> {
    try {
      const response = await this.openai.chat.completions.create({
        model: config.openai.model,
        messages: [
          {
            role: 'system',
            content: 'Generate a concise, descriptive title (3-6 words) for this learning session. The title should capture the main topic or concept discussed. Use the same language as the transcript. Be specific and informative. Examples: "Understanding Neural Networks", "Photosynthesis Process Explained", "量子力学基础概念", "React Hooks深入理解".',
          },
          {
            role: 'user',
            content: `Generate a title for this session:\n\n${transcript.slice(0, 500)}`,
          },
        ],
        temperature: 0.3,
        max_tokens: 20,
      });

      return response.choices[0].message.content?.trim() || 'Learning Session';
    } catch (error) {
      console.error('Title generation error:', error);
      return 'Learning Session';
    }
  }
}

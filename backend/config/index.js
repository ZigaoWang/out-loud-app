"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
exports.config = {
    port: process.env.PORT || 3000,
    soniox: {
        apiKey: process.env.SONIOX_API_KEY || '',
        wsUrl: 'wss://stt-rt.soniox.com/transcribe-websocket', // FIXED: Correct Soniox URL
        model: 'stt-rt-preview',
    },
    openai: {
        apiKey: process.env.OPENAI_API_KEY || '',
        baseUrl: (process.env.OPENAI_BASE_URL || 'https://api.uniapi.io') + '/v1',
        model: 'gpt-4.1', // UniAPI model
    },
};

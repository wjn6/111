import { generateRequestBody } from '../src/utils/utils.js';

// 测试用例：包含工具调用的对话
const messages = [
  {
    role: "user",
    content: "查询天气"
  },
  {
    role: "assistant",
    content: null,
    tool_calls: [
      {
        id: "call_123",
        type: "function",
        function: {
          name: "get_weather",
          arguments: JSON.stringify({ city: "北京" })
        }
      }
    ]
  },
  {
    role: "tool",
    tool_call_id: "call_123",
    content: "北京今天晴天，温度20度"
  },
  {
    role: "assistant",
    content: "北京今天是晴天，温度20度。"
  }
];

const tools = [
  {
    type: "function",
    function: {
      name: "get_weather",
      description: "获取天气信息",
      parameters: {
        type: "object",
        properties: {
          city: {
            type: "string",
            description: "城市名称"
          }
        },
        required: ["city"]
      }
    }
  }
];

const requestBody = generateRequestBody(messages, "claude-sonnet-4-5", {}, tools);

console.log(JSON.stringify(requestBody, null, 2));

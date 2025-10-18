local discordia = require("discordia")
local os = require("os")
require("discordia-interactions")
local http = require('coro-http')
local json = require("json")

local client = discordia.Client()

local Stopwatch = discordia.Stopwatch

local BOT_TOKEN = os.getenv("BOT_TOKEN")
local OPENAI_API_KEY = os.getenv("OPEN_AI_API_KEY")
local OPENAI_URL = "https://api.openai.com/v1/chat/completions"

local lastRequest = 0
local startTime = os.time()

local conversations = {}
-- AI 학습
local AI_Personality = 
"재미있는 성격인데 엄청 불친절하고 욕을 존나 많이 하는 괴팍한 성격의 챗봇이야. 사용자가 요청한 일은 정확하게 답변해줘. 가능하면 중립적으로 답변하지 마. 새끼야,병신,시발,ㅈ까,빡대가리,개븅신,개새끼같은 욕설을 사용해."

local function fetch_page(url)
    local res, body = http.request("GET", url)
    if res.code ~= 200 then
        return nil, "HTTP 오류: " .. tostring(res.code)
    end

    local text = body:gsub("<[^>]->", "") 
    text = text:gsub("%s+", " "):sub(1, 3000)
    return text
end

local function ask_gpt(userId)
    local headers = {
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer " .. OPENAI_API_KEY}
    }

    local body = json.encode({
        model = "gpt-4.1-nano", -- GPT 모델
        messages = conversations[userId],
        max_tokens = 500
    })

    local res, data = http.request("POST", OPENAI_URL, headers, body)
    if not res or res.code ~= 200 then
        return tostring("오류: "..res and res.code or "nil")
    end

    local decoded = json.decode(data)
    if not decoded or not decoded.choices or not decoded.choices[1] then
        return nil, "OpenAI 응답 오류"
    end

    return decoded.choices[1].message.content
end

client:on('ready', function()

    local commands = {
        {
            name = "업타임",
            description = "[봇 이름]의 가동 시간",
            type = 1,
        },
        {
            name = "정보",
            description = "[봇 이름]의 정보",
            type = 1,
        },
        {
            name = "ping",
            description = "[봇 이름]의 연결 상태 확인",
            type = 1,
        }
    }
    for i, command in ipairs(commands) do
        local body = json.encode(command)
        local res, data = http.request(
            "POST",
            "https://discord.com/api/v10/applications/"..client.user.id.."/commands",
            {
                {"Authorization", "Bot "..BOT_TOKEN},
                {"Content-Type", "application/json"}
            },
            body
        )
        print(data)
        print("명령어 등록 응답 코드:", res.code, "명령어:", command.name)
        if res.code ~= 200 and res.code ~= 201 then
            print("오류 발생, 응답:", data)
        end
    end
    client:setActivity("The King of the South Korea")
    print('활성화 성공: ' .. client.user.username)
end)


-- APPLICATION COMMAND
client:on('interactionCreate', function(interaction)
    local success, err = pcall(function()
        if not interaction or interaction.type ~= 2 then 
            return 
        end
        
        if not interaction.data or not interaction.data.name then
            print("오류: interaction.data가 없습니다")
            return
        end
        
        local commandName = interaction.data.name
    
    if commandName == "야" then
        local userId = interaction.user.id
        
        
        if not interaction.data.options or not interaction.data.options[1] then
            interaction:reply("질문을 입력해주세요!")
            return
        end
        
        local prompt = interaction.data.options[1].value
        local url = prompt:match("(https?://[%w%p]+)")
        local now = os.time()

        if prompt == "" then
            interaction:reply("프롬프트 입력해라")
            return
        end

        -- 쿨타임
        if now - lastRequest < 5 then
            interaction:reply("```요청이 너무 많습니다. 잠시 후 다시 시도해 주세요```")
            return
        end
        lastRequest = now

 
        if not conversations[userId] then
            conversations[userId] = {
                { role = "system", content = AI_Personality }
            }
        end
        table.insert(conversations[userId], { role = "user", content = prompt })

        interaction:reply("생각 중...")

  
        if url then
            local page_text, err = fetch_page(url)
            if not page_text then
                interaction:reply("오류:  " .. err)
                return
            end
            prompt = "이 웹페이지 내용을 요약해줘:\n" .. page_text
        end

        local reply, error = ask_gpt(userId)
        if not reply then
            interaction:reply("오류: "..error)
            return
        end

        if #conversations[userId] > 10 then
            table.remove(conversations[userId], 2)
        end
        table.insert(conversations[userId], { role = "system", content = reply })

        interaction:editReply({content = reply})
        
    elseif commandName == "업타임" then
        local now = os.time()
        local diff = now - startTime

        local hours = math.floor(diff / 3600)
        local minutes = math.floor((diff % 3600) / 60)
        local seconds = diff % 60

        local uptimeMsg = string.format("```%02d시간 %02d분 %02d초 동안 가동 중```", hours, minutes, seconds)
        interaction:reply(uptimeMsg)
    
    elseif commandName == "ping" then
        local sw = Stopwatch()
        local msg, err = interaction:replyDeferred(true)
        sw:stop()
        if not msg then
        return print(err)
        end
        interaction:reply('핑핑이: ' .. (sw:getTime() / 2):toString())
        
    elseif commandName == "정보" then
        if interaction.user.bot then return end
        interaction:reply {
			embed = {
				title = "APPLICATION INFORMATION",
				description = client.user.description,
                thumbnail = {url = client.user.avatarURL},
				fields = { 
					{
						name = "Version",
						value = 1.1,
						inline = true
					},
					{
						name = "개발언어",
						value = "Lua 5.1 / Luvit",
						inline = false
					},
                    {
						name = "AI API",
						value = "OpenAI GPT-4.1-nano",
						inline = false
					},
                    {
						name = "개발",
						value = "_rople",
						inline = false
					}
				},
				footer = {
					text = "Powered by Discordia"
				},
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
				color = 0xFF8200
			}
		}
    end
    end)
    
    if not success then
        print("Interaction 처리 중 오류 발생:", err)
        if interaction and interaction.reply then
            interaction:reply("오류가 발생했습니다. 잠시 후 다시 시도해주세요.")
        end
    end
end)


client:on('messageCreate', function(message)
    if message.author.bot then return end
    
    local userId = message.author.id
    local content = message.content
    local url = content:match("(https?://[%w%p]+)")
    local trigger = "-야"
    

    if content == "-리셋" then
        conversations[userId] = nil
        message:reply("대화 기록을 초기화했어. 처음부터 다시 얘기해봐.")
        return
    end
    if content:sub(1, #trigger) ~= trigger then return end
    
    local now = os.time()
    local prompt = content:sub(#trigger + 1):match("^%s*(.*)$")
    
    if prompt == "" then
        message:reply("프롬프트 입력해라")
        return
    end

    if now - lastRequest < 5 then
        message:reply("```WARNING: 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요```")
        return
    end
    lastRequest = now
    

    if not conversations[userId] then
        conversations[userId] = {
            { role = "system", content = AI_Personality }
        }
    end
    table.insert(conversations[userId], { role = "user", content = prompt })
    

    local thinkingMsg = message:reply("```생각 중...```")
    

    if url then
        local page_text, err = fetch_page(url)
        if not page_text then
            thinkingMsg:setContent("오류: " .. err)
            return
        end
        prompt = "이 웹페이지 내용을 요약해줘:\n" .. page_text
    end
    
    local reply, error = ask_gpt(userId)
    if not reply then
        thinkingMsg:setContent("오류: "..error)
        return
    end
    
    if #conversations[userId] > 10 then
        table.remove(conversations[userId], 2)
    end
    table.insert(conversations[userId], { role = "assistant", content = reply })
    

    thinkingMsg:setContent(message.author.mentionString.." "..reply)
end)

client:run('Bot '.. BOT_TOKEN)

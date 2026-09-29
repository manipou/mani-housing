local Util = {}

local Webhook = ''

---@param Job string
---@param Amount number
function Util.AddMoneyForJob(Job, Amount)

end

---@param Source number
---@param Message string
function Util.Log(Source, Message)
    exports['mani-bridge']:DiscordWebhook(Source, {
        Webhook = Webhook,
        Resource = 'Mani-Housing',
        Message = Message
    })
end

return Util
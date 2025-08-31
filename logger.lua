local config = require('cant_read/config')

local logger = {}

local logFile
local debugFile
local currentDate

local stats = {
  total = 0,
  byChannel = {},
  dropped_prelog = 0,
  lastEmit = os.time(),
}

local function openLog()
  local date = os.date('!%Y-%m-%d')
  local dir = config.Log.Dir
  local filename
  if config.Log.RotateDaily then
    filename = string.format('%s/ChatLog-%s.txt', dir, date)
  else
    filename = string.format('%s/ChatLog.txt', dir)
  end
  if currentDate ~= date or not logFile then
    if logFile then logFile:close() end
    logFile = io.open(filename, 'a')
    currentDate = date
  end
end

local function openDebug()
  if not config.Log.Debug then return end
  if not debugFile then
    local dir = config.Log.Dir
    local filename = string.format('%s/ChatLog-Debug.txt', dir)
    debugFile = io.open(filename, 'a')
  end
end

local function emitStats(now)
  if not config.Log.Debug then return end
  if now - stats.lastEmit < 60 then return end
  openDebug()
  local parts = {}
  for k,v in pairs(stats.byChannel) do
    table.insert(parts, string.format('%s:%d', k, v))
  end
  debugFile:write(string.format('[STATS] total=%d byChannel={%s} dropped_prelog=%d\n', stats.total, table.concat(parts, ','), stats.dropped_prelog))
  debugFile:flush()
  stats.lastEmit = now
end

function logger.log(channel, speaker, message)
  openLog()
  local now = os.time()
  local msec = math.floor((os.clock()*1000)%1000)
  local iso = os.date('!%Y-%m-%dT%H:%M:%S', now)..string.format('.%03dZ', msec)
  speaker = speaker or ''
  message = message or ''
  local esc = message:gsub('\t','\\t'):gsub('\n','\\n')
  local line = string.format('%s\t%s\t%s\t%s\n', iso, channel, speaker, esc)
  local ok = logFile:write(line)
  if not ok then
    openLog()
    logFile:write(line)
  end
  logFile:flush()
  if config.Log.Debug then
    openDebug()
    debugFile:write('[RAW] '..line)
    debugFile:flush()
  end
  stats.total = stats.total + 1
  stats.byChannel[channel] = (stats.byChannel[channel] or 0) + 1
  emitStats(now)
end

function logger.debug(prefix, channel, speaker, message)
  if not config.Log.Debug then return end
  openDebug()
  local now = os.time()
  local msec = math.floor((os.clock()*1000)%1000)
  local iso = os.date('!%Y-%m-%dT%H:%M:%S', now)..string.format('.%03dZ', msec)
  speaker = speaker or ''
  message = message or ''
  local esc = message:gsub('\t','\\t'):gsub('\n','\\n')
  debugFile:write(string.format('[%s] %s\t%s\t%s\t%s\n', prefix, iso, channel, speaker, esc))
  debugFile:flush()
end

return logger

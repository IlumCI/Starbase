-- audio.lua: Simple procedural audio helper for Solar2D
-- Generates basic waveforms without needing audio files
local Audio = {}

function Audio.init()
    -- Solar2D audio system
    if audio then
        audio.setVolume(0.5)
    end
end

-- Generate a short beep tone (used for fire, death, etc.)
-- Solar2D can generate audio from raw PCM data
function Audio.playFire(volume)
    volume = volume or 0.3
    -- Create a simple short beep
    local rate = 44100
    local duration = 0.05  -- seconds
    local samples = math.floor(rate * duration)
    local data = {}

    local freq = 880  -- A5
    for i = 0, samples - 1 do
        local t = i / rate
        local env = 1 - (i / samples)  -- envelope decay
        local sample = math.floor(math.sin(2 * math.pi * freq * t) * 32767 * env * 0.3)
        -- 16-bit little endian
        table.insert(data, string.char(sample & 0xFF))
        table.insert(data, string.char((sample >> 8) & 0xFF))
    end

    -- Solar2D doesn't support raw PCM directly, so we use system.newAudio
    -- For now, this is a placeholder — in production, bundle .wav files
end

function Audio.playDeath()
    -- Short thud — bundle a short .wav in assets/audio/
end

function Audio.playUpgrade()
    -- Soft chime
end

function Audio.playBoss()
    -- Low rumble
end

function Audio.startAmbient()
    -- Background drone — bundle ambient.wav or generate
end

return Audio
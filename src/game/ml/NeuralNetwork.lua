-- NeuralNetwork: pure Lua feedforward neural network.
-- No external dependencies. Designed for real-time game use.
-- Supports: sigmoid, tanh, ReLU, LeakyReLU activations.
-- Serializes to plain Lua tables for save/load.

local NN = {}
NN.__index = NN

-- ─────────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────────
-- layers: array of layer sizes, e.g. {4, 8, 3}
-- activation: "sigmoid" | "tanh" | "relu" | "leaky" (default: "leaky")
function NN.new(layers, activation)
    local self = setmetatable({}, NN)
    self.layers = {}          -- layer sizes
    self.weights = {}         -- w[l][i][j] = weight from neuron j in layer l-1 to neuron i in layer l
    self.biases = {}           -- b[l][i] = bias of neuron i in layer l
    self.activation = activation or "leaky"
    self:init(layers)
    return self
end

-- Initialize with given layer sizes (fresh random weights)
function NN:init(layers)
    self.layers = {}
    for _, v in ipairs(layers) do table.insert(self.layers, v) end
    self.weights = {}
    self.biases = {}

    for l = 2, #layers do
        local inSize = layers[l - 1]
        local outSize = layers[l]

        -- Xavier/He-inspired uniform init: sqrt(6 / (in + out))
        local scale = math.sqrt(6.0 / (inSize + outSize))

        -- Weights: [l][i][j] — layer l, output neuron i, input neuron j
        self.weights[l] = {}
        self.biases[l] = {}
        for i = 1, outSize do
            self.weights[l][i] = {}
            for j = 1, inSize do
                self.weights[l][i][j] = math.random() * 2 * scale - scale
            end
            self.biases[l][i] = math.random() * 2 * scale - scale
        end
    end
end

-- ─────────────────────────────────────────────────────────────────
-- Activation functions
-- ─────────────────────────────────────────────────────────────────
function NN:_act(x)
    local a = self.activation
    if a == "sigmoid" then
        return 1.0 / (1.0 + math.exp(-math.max(-60, math.min(60, x))))
    elseif a == "tanh" then
        return math.tanh(x)
    elseif a == "relu" then
        return x > 0 and x or 0
    else -- "leaky" default
        return x > 0 and x or x * 0.01
    end
end

-- Derivative of activation (used by train())
function NN:_actDeriv(x)
    local a = self.activation
    if a == "sigmoid" then
        local s = self:_act(x)
        return s * (1 - s)
    elseif a == "tanh" then
        local t = math.tanh(x)
        return 1 - t * t
    elseif a == "relu" then
        return x > 0 and 1 or 0
    else -- "leaky"
        return x > 0 and 1 or 0.01
    end
end

-- ─────────────────────────────────────────────────────────────────
-- Forward pass
-- ─────────────────────────────────────────────────────────────────
-- input: table of numbers, length = layers[1]
-- returns: table of numbers, length = layers[#layers]
function NN:forward(input)
    local n = #input
    if n ~= self.layers[1] then
        error("NN: input size mismatch: expected " .. self.layers[1] .. ", got " .. n)
    end

    -- Store activations per layer for backprop
    self._acts = {}
    self._preacts = {}
    self._acts[1] = {}
    for i = 1, n do self._acts[1][i] = input[i] end

    for l = 2, #self.layers do
        self._acts[l] = {}
        self._preacts[l] = {}
        local outSize = self.layers[l]
        for i = 1, outSize do
            local sum = self.biases[l][i]
            for j = 1, self.layers[l - 1] do
                sum = sum + self.weights[l][i][j] * self._acts[l - 1][j]
            end
            self._preacts[l][i] = sum
            self._acts[l][i] = self:_act(sum)
        end
    end

    return self._acts[#self._acts]
end

-- Quick forward without storing activations (for inference after training)
function NN:predict(input)
    local n = #input
    local prev = {}
    for i = 1, n do prev[i] = input[i] end

    for l = 2, #self.layers do
        local out = {}
        for i = 1, self.layers[l] do
            local sum = self.biases[l][i]
            for j = 1, self.layers[l - 1] do
                sum = sum + self.weights[l][i][j] * prev[j]
            end
            out[i] = self:_act(sum)
        end
        prev = out
    end
    return prev
end

-- ─────────────────────────────────────────────────────────────────
-- Backpropagation training (single sample)
-- ─────────────────────────────────────────────────────────────────
-- input, target: tables of numbers
-- returns: average loss (MSE)
function NN:train(input, target, learningRate)
    learningRate = learningRate or 0.01
    local output = self:forward(input)

    local L = #self.layers
    local nOut = self.layers[L]

    -- Output layer error: (output - target) * deriv
    local err = {}
    for i = 1, nOut do
        local t = target[i] or 0
        err[i] = (output[i] - t) * self:_actDeriv(self._preacts[L][i])
    end

    -- Backprop through layers
    for l = L, 2, -1 do
        -- Compute gradients for weights/biases at layer l
        for i = 1, self.layers[l] do
            for j = 1, self.layers[l - 1] do
                self.weights[l][i][j] = self.weights[l][i][j] - learningRate * err[i] * self._acts[l - 1][j]
            end
            self.biases[l][i] = self.biases[l][i] - learningRate * err[i]
        end

        -- Backprop error to previous layer
        if l > 2 then
            local newErr = {}
            for j = 1, self.layers[l - 1] do
                local sum = 0
                for i = 1, self.layers[l] do
                    sum = sum + self.weights[l][i][j] * err[i]
                end
                newErr[j] = sum * self:_actDeriv(self._preacts[l - 1][j])
            end
            err = newErr
        end
    end

    -- Compute MSE loss
    local loss = 0
    for i = 1, nOut do
        local t = target[i] or 0
        local d = output[i] - t
        loss = loss + d * d
    end
    return loss / nOut
end

-- Train on a batch of samples (shuffled internally)
function NN:trainBatch(samples, learningRate, epochs)
    learningRate = learningRate or 0.05
    epochs = epochs or 1
    local totalLoss = 0
    local count = 0

    for ep = 1, epochs do
        -- Shuffle samples
        for i = #samples, 2, -1 do
            local j = math.random(i)
            samples[i], samples[j] = samples[j], samples[i]
        end

        for _, s in ipairs(samples) do
            totalLoss = totalLoss + self:train(s.input, s.target, learningRate)
            count = count + 1
        end
    end

    return totalLoss / math.max(1, count)
end

-- ─────────────────────────────────────────────────────────────────
-- Utility: clone (deep copy)
-- ─────────────────────────────────────────────────────────────────
function NN:clone()
    local copy = setmetatable({}, NN)
    copy.layers = {}
    for i = 1, #self.layers do copy.layers[i] = self.layers[i] end
    copy.weights = {}
    copy.biases = {}
    copy.activation = self.activation
    for l = 2, #self.layers do
        copy.weights[l] = {}
        copy.biases[l] = {}
        for i = 1, self.layers[l] do
            copy.weights[l][i] = {}
            for j = 1, self.layers[l - 1] do
                copy.weights[l][i][j] = self.weights[l][i][j]
            end
            copy.biases[l][i] = self.biases[l][i]
        end
    end
    return copy
end

-- ─────────────────────────────────────────────────────────────────
-- Serialization (for Persistence)
-- ─────────────────────────────────────────────────────────────────
function NN:serialize()
    local data = {
        layers = self.layers,
        activation = self.activation,
        weights = self.weights,
        biases = self.biases,
    }
    return data
end

function NN.deserialize(data)
    local self = setmetatable({}, NN)
    self.layers = data.layers
    self.activation = data.activation or "leaky"
    self.weights = data.weights
    self.biases = data.biases
    return self
end

-- ─────────────────────────────────────────────────────────────────
-- Loss functions (MSE for regression, cross-entropy stubs)
-- ─────────────────────────────────────────────────────────────────
function NN.mse(output, target)
    local loss = 0
    for i = 1, #output do
        local d = (output[i] or 0) - (target[i] or 0)
        loss = loss + d * d
    end
    return loss / #output
end

-- Normalize a vector to unit length (useful for input preprocessing)
function NN.normalize(vec)
    local sum = 0
    for i = 1, #vec do sum = sum + vec[i] * vec[i] end
    local len = math.sqrt(sum)
    if len < 1e-8 then return vec end
    local out = {}
    for i = 1, #vec do out[i] = vec[i] / len end
    return out
end

-- Clamp vector values to [minV, maxV]
function NN.clamp(vec, minV, maxV)
    local out = {}
    for i = 1, #vec do
        out[i] = math.max(minV, math.min(maxV, vec[i]))
    end
    return out
end

return NN

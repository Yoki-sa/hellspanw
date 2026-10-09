--[[
	Png
	A dependency-free PNG encoder written in pure Luau.

	Images are emitted as 8-bit RGBA, unfiltered, wrapped in a zlib stream made
	of *stored* (uncompressed) deflate blocks. That keeps the encoder tiny and
	fast in an interpreted VM while still producing a 100% spec-valid file that
	any decoder (including Roblox's) accepts.

	Png.encode(width, height, pixels) -> string
		pixels: buffer of width * height * 4 bytes (RGBA, row-major, top-down)
]]

local Png = {}

local band, bxor, bnot, rshift, lshift, bor = bit32.band, bit32.bxor, bit32.bnot, bit32.rshift, bit32.lshift, bit32.bor
local readu8, writeu8 = buffer.readu8, buffer.writeu8

local SIGNATURE = { 137, 80, 78, 71, 13, 10, 26, 10 }
local MAX_STORED = 65535

-- CRC-32 (IEEE 802.3), table driven.
local CRC_TABLE = table.create(256, 0)
for n = 0, 255 do
	local c = n
	for _ = 1, 8 do
		if band(c, 1) == 1 then
			c = bxor(0xEDB88320, rshift(c, 1))
		else
			c = rshift(c, 1)
		end
	end
	CRC_TABLE[n + 1] = c
end

local function crc32(buf, offset, length)
	local crc = 0xFFFFFFFF
	for i = offset, offset + length - 1 do
		crc = bxor(CRC_TABLE[band(bxor(crc, readu8(buf, i)), 0xFF) + 1], rshift(crc, 8))
	end
	return bnot(crc)
end

-- Adler-32, with deferred modulo (5552 is the largest run that cannot overflow).
local function adler32(buf, offset, length)
	local a, b = 1, 0
	local i = offset
	local stop = offset + length
	while i < stop do
		local runEnd = math.min(i + 5552, stop)
		for j = i, runEnd - 1 do
			a += readu8(buf, j)
			b += a
		end
		a %= 65521
		b %= 65521
		i = runEnd
	end
	return bor(lshift(b, 16), a)
end

Png.crc32 = crc32
Png.adler32 = adler32

function Png.encode(width, height, pixels)
	assert(width > 0 and height > 0, "Png.encode: image must be at least 1x1")
	assert(buffer.len(pixels) >= width * height * 4, "Png.encode: pixel buffer too small")

	local rowBytes = width * 4 + 1
	local rawSize = rowBytes * height

	-- Scanlines, each prefixed with filter type 0 (None).
	local raw = buffer.create(rawSize)
	for y = 0, height - 1 do
		-- filter byte is already 0 from buffer.create
		buffer.copy(raw, y * rowBytes + 1, pixels, y * width * 4, width * 4)
	end

	local blocks = math.max(1, math.ceil(rawSize / MAX_STORED))
	local zlibSize = 2 + rawSize + blocks * 5 + 4
	local total = #SIGNATURE + (12 + 13) + (12 + zlibSize) + 12
	local out = buffer.create(total)
	local pos = 0

	local function u8(v)
		writeu8(out, pos, v)
		pos += 1
	end

	local function u16le(v)
		writeu8(out, pos, band(v, 0xFF))
		writeu8(out, pos + 1, band(rshift(v, 8), 0xFF))
		pos += 2
	end

	local function u32be(v)
		writeu8(out, pos, band(rshift(v, 24), 0xFF))
		writeu8(out, pos + 1, band(rshift(v, 16), 0xFF))
		writeu8(out, pos + 2, band(rshift(v, 8), 0xFF))
		writeu8(out, pos + 3, band(v, 0xFF))
		pos += 4
	end

	local function tag(name)
		buffer.writestring(out, pos, name)
		pos += 4
	end

	for _, byte in SIGNATURE do
		u8(byte)
	end

	-- IHDR
	u32be(13)
	local chunkStart = pos
	tag("IHDR")
	u32be(width)
	u32be(height)
	u8(8) -- bit depth
	u8(6) -- colour type: truecolour + alpha
	u8(0) -- compression: deflate
	u8(0) -- filter method
	u8(0) -- interlace: none
	u32be(crc32(out, chunkStart, pos - chunkStart))

	-- IDAT
	u32be(zlibSize)
	chunkStart = pos
	tag("IDAT")
	u8(0x78) -- CMF: deflate, 32K window
	u8(0x01) -- FLG: no dict, fastest; (0x7801 % 31 == 0)

	local offset = 0
	repeat
		local len = math.min(MAX_STORED, rawSize - offset)
		local final = offset + len >= rawSize
		u8(final and 1 or 0) -- BFINAL + BTYPE=00 (stored)
		u16le(len)
		u16le(bxor(len, 0xFFFF))
		buffer.copy(out, pos, raw, offset, len)
		pos += len
		offset += len
	until final

	u32be(adler32(raw, 0, rawSize))
	u32be(crc32(out, chunkStart, pos - chunkStart))

	-- IEND
	u32be(0)
	chunkStart = pos
	tag("IEND")
	u32be(crc32(out, chunkStart, 4))

	assert(pos == total, "Png.encode: size mismatch")
	return buffer.tostring(out)
end

return Png

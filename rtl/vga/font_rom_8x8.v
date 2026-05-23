//------------------------------------------------------------------------------
// font_rom_8x8.v - font 5x7 đơn giản đặt trong ô 8x8.
// Hỗ trợ chữ số, A-Z, khoảng trắng, :, /, -, ., X.
//------------------------------------------------------------------------------
module font_rom_8x8(
    input  wire [7:0] char_code,
    input  wire [2:0] row,
    output reg  [7:0] bits
);

always @(*) begin
    bits = 8'b00000000;
    case (char_code)
        "0": case(row) 0:bits=8'b01110000;1:bits=8'b10001000;2:bits=8'b10011000;3:bits=8'b10101000;4:bits=8'b11001000;5:bits=8'b10001000;6:bits=8'b01110000;default:bits=0; endcase
        "1": case(row) 0:bits=8'b00100000;1:bits=8'b01100000;2:bits=8'b00100000;3:bits=8'b00100000;4:bits=8'b00100000;5:bits=8'b00100000;6:bits=8'b01110000;default:bits=0; endcase
        "2": case(row) 0:bits=8'b01110000;1:bits=8'b10001000;2:bits=8'b00001000;3:bits=8'b00010000;4:bits=8'b00100000;5:bits=8'b01000000;6:bits=8'b11111000;default:bits=0; endcase
        "3": case(row) 0:bits=8'b11110000;1:bits=8'b00001000;2:bits=8'b00001000;3:bits=8'b01110000;4:bits=8'b00001000;5:bits=8'b00001000;6:bits=8'b11110000;default:bits=0; endcase
        "4": case(row) 0:bits=8'b00010000;1:bits=8'b00110000;2:bits=8'b01010000;3:bits=8'b10010000;4:bits=8'b11111000;5:bits=8'b00010000;6:bits=8'b00010000;default:bits=0; endcase
        "5": case(row) 0:bits=8'b11111000;1:bits=8'b10000000;2:bits=8'b11110000;3:bits=8'b00001000;4:bits=8'b00001000;5:bits=8'b10001000;6:bits=8'b01110000;default:bits=0; endcase
        "6": case(row) 0:bits=8'b00110000;1:bits=8'b01000000;2:bits=8'b10000000;3:bits=8'b11110000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b01110000;default:bits=0; endcase
        "7": case(row) 0:bits=8'b11111000;1:bits=8'b00001000;2:bits=8'b00010000;3:bits=8'b00100000;4:bits=8'b01000000;5:bits=8'b01000000;6:bits=8'b01000000;default:bits=0; endcase
        "8": case(row) 0:bits=8'b01110000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b01110000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b01110000;default:bits=0; endcase
        "9": case(row) 0:bits=8'b01110000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b01111000;4:bits=8'b00001000;5:bits=8'b00010000;6:bits=8'b01100000;default:bits=0; endcase
        "A": case(row) 0:bits=8'b01110000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b11111000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b10001000;default:bits=0; endcase
        "B": case(row) 0:bits=8'b11110000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b11110000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b11110000;default:bits=0; endcase
        "C": case(row) 0:bits=8'b01110000;1:bits=8'b10001000;2:bits=8'b10000000;3:bits=8'b10000000;4:bits=8'b10000000;5:bits=8'b10001000;6:bits=8'b01110000;default:bits=0; endcase
        "D": case(row) 0:bits=8'b11100000;1:bits=8'b10010000;2:bits=8'b10001000;3:bits=8'b10001000;4:bits=8'b10001000;5:bits=8'b10010000;6:bits=8'b11100000;default:bits=0; endcase
        "E": case(row) 0:bits=8'b11111000;1:bits=8'b10000000;2:bits=8'b10000000;3:bits=8'b11110000;4:bits=8'b10000000;5:bits=8'b10000000;6:bits=8'b11111000;default:bits=0; endcase
        "F": case(row) 0:bits=8'b11111000;1:bits=8'b10000000;2:bits=8'b10000000;3:bits=8'b11110000;4:bits=8'b10000000;5:bits=8'b10000000;6:bits=8'b10000000;default:bits=0; endcase
        "G": case(row) 0:bits=8'b01110000;1:bits=8'b10001000;2:bits=8'b10000000;3:bits=8'b10111000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b01111000;default:bits=0; endcase
        "H": case(row) 0:bits=8'b10001000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b11111000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b10001000;default:bits=0; endcase
        "I": case(row) 0:bits=8'b01110000;1:bits=8'b00100000;2:bits=8'b00100000;3:bits=8'b00100000;4:bits=8'b00100000;5:bits=8'b00100000;6:bits=8'b01110000;default:bits=0; endcase
        "J": case(row) 0:bits=8'b00111000;1:bits=8'b00010000;2:bits=8'b00010000;3:bits=8'b00010000;4:bits=8'b10010000;5:bits=8'b10010000;6:bits=8'b01100000;default:bits=0; endcase
        "K": case(row) 0:bits=8'b10001000;1:bits=8'b10010000;2:bits=8'b10100000;3:bits=8'b11000000;4:bits=8'b10100000;5:bits=8'b10010000;6:bits=8'b10001000;default:bits=0; endcase
        "L": case(row) 0:bits=8'b10000000;1:bits=8'b10000000;2:bits=8'b10000000;3:bits=8'b10000000;4:bits=8'b10000000;5:bits=8'b10000000;6:bits=8'b11111000;default:bits=0; endcase
        "M": case(row) 0:bits=8'b10001000;1:bits=8'b11011000;2:bits=8'b10101000;3:bits=8'b10101000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b10001000;default:bits=0; endcase
        "N": case(row) 0:bits=8'b10001000;1:bits=8'b11001000;2:bits=8'b10101000;3:bits=8'b10011000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b10001000;default:bits=0; endcase
        "O": case(row) 0:bits=8'b01110000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b10001000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b01110000;default:bits=0; endcase
        "P": case(row) 0:bits=8'b11110000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b11110000;4:bits=8'b10000000;5:bits=8'b10000000;6:bits=8'b10000000;default:bits=0; endcase
        "Q": case(row) 0:bits=8'b01110000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b10001000;4:bits=8'b10101000;5:bits=8'b10010000;6:bits=8'b01101000;default:bits=0; endcase
        "R": case(row) 0:bits=8'b11110000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b11110000;4:bits=8'b10100000;5:bits=8'b10010000;6:bits=8'b10001000;default:bits=0; endcase
        "S": case(row) 0:bits=8'b01111000;1:bits=8'b10000000;2:bits=8'b10000000;3:bits=8'b01110000;4:bits=8'b00001000;5:bits=8'b00001000;6:bits=8'b11110000;default:bits=0; endcase
        "T": case(row) 0:bits=8'b11111000;1:bits=8'b00100000;2:bits=8'b00100000;3:bits=8'b00100000;4:bits=8'b00100000;5:bits=8'b00100000;6:bits=8'b00100000;default:bits=0; endcase
        "U": case(row) 0:bits=8'b10001000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b10001000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b01110000;default:bits=0; endcase
        "V": case(row) 0:bits=8'b10001000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b10001000;4:bits=8'b10001000;5:bits=8'b01010000;6:bits=8'b00100000;default:bits=0; endcase
        "W": case(row) 0:bits=8'b10001000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b10101000;4:bits=8'b10101000;5:bits=8'b11011000;6:bits=8'b10001000;default:bits=0; endcase
        "X": case(row) 0:bits=8'b10001000;1:bits=8'b10001000;2:bits=8'b01010000;3:bits=8'b00100000;4:bits=8'b01010000;5:bits=8'b10001000;6:bits=8'b10001000;default:bits=0; endcase
        "Y": case(row) 0:bits=8'b10001000;1:bits=8'b10001000;2:bits=8'b01010000;3:bits=8'b00100000;4:bits=8'b00100000;5:bits=8'b00100000;6:bits=8'b00100000;default:bits=0; endcase
        "Z": case(row) 0:bits=8'b11111000;1:bits=8'b00001000;2:bits=8'b00010000;3:bits=8'b00100000;4:bits=8'b01000000;5:bits=8'b10000000;6:bits=8'b11111000;default:bits=0; endcase
        "a": case(row) 0:bits=8'b01110000;1:bits=8'b10001000;2:bits=8'b10001000;3:bits=8'b11111000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b10001000;default:bits=0; endcase
        "e": case(row) 0:bits=8'b11111000;1:bits=8'b10000000;2:bits=8'b10000000;3:bits=8'b11110000;4:bits=8'b10000000;5:bits=8'b10000000;6:bits=8'b11111000;default:bits=0; endcase
        "g": case(row) 0:bits=8'b01110000;1:bits=8'b10001000;2:bits=8'b10000000;3:bits=8'b10111000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b01111000;default:bits=0; endcase
        "m": case(row) 0:bits=8'b10001000;1:bits=8'b11011000;2:bits=8'b10101000;3:bits=8'b10101000;4:bits=8'b10001000;5:bits=8'b10001000;6:bits=8'b10001000;default:bits=0; endcase
        ":": case(row) 1:bits=8'b00100000;2:bits=8'b00100000;4:bits=8'b00100000;5:bits=8'b00100000;default:bits=0; endcase
        "/": case(row) 0:bits=8'b00001000;1:bits=8'b00010000;2:bits=8'b00010000;3:bits=8'b00100000;4:bits=8'b01000000;5:bits=8'b01000000;6:bits=8'b10000000;default:bits=0; endcase
        "-": case(row) 3:bits=8'b11111000;default:bits=0; endcase
        ".": case(row) 6:bits=8'b00100000;default:bits=0; endcase
        default: bits = 8'b00000000;
    endcase
end
endmodule

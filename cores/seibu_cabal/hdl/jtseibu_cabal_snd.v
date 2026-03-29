/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: JTCORES team.
    Date: 2026-03-28

*/

module jtseibu_cabal_snd(
    input         clk,
    input         rst,
    input         snd_cen,
    // ROM
    output [16:0] rom_addr,
    input  [7:0]  rom_dout,
    // Sound output
    output [9:0]  snd_lv,
    output [9:0]  snd_rv
);

    // Stub - all outputs disabled
    assign rom_addr = 17'h0;
    assign snd_lv   = 10'h0;
    assign snd_rv   = 10'h0;

endmodule

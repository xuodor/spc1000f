iverilog -I cpu -I vdg -I usb \
         top_tb.v top.v clock_sim.v memory.v key_matrix.v i2s.v \
         sdram/*.v usb/*.v seg_disp/*.v cpu/*.v psg/*.v vdg/*.v \
         -o top.vvp \
&& vvp top.vvp

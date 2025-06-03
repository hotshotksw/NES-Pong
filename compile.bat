cd ..

cc65\bin\ca65 final\cart.s -o final\cart.o -t nes
cc65\bin\ld65 final\cart.o -o final\cart.nes -t nes

cd final
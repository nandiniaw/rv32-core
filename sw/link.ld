SECTIONS
{
  . = 0x80000000;
  .text : { *(.text*) }
  . = ALIGN(0x1000);
  .tohost : ALIGN(64) { *(.tohost) }
}

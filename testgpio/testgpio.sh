#!/bin/bash

## Script para teste de LCD 16x2 conectado a GPIOs na BeagleBone Black
## Baseado nos comandos em http://elinux.org/BeagleBone/I2CLCDDemo
## Autor: Rodrigo Montalvao (montalvao@gmail.com) -- 2016

## GPIO Expander : Philips PCF8574AT
## LCD Display   : Hitachi HD44780

## O driver do IO Expander (modulo pcf857x) disponibiliza 8 GPIOs para conexao.
## Esses GPIOs sao numados de 248 a 255, segundo informado pelo log:
## gpiochip_add: registered GPIOs 248 to 255 on device: pcf8574a

GPIO_DIR='/sys/class/gpio'

# Bits 0-7 sao representados pelos GPIOs 255~248, sendo o bit do GPIO 248
# o mais significativo.
GPIOS=( GPIO_255 GPIO_254 GPIO_253 GPIO_252 GPIO_251 GPIO_250 GPIO_249 GPIO_248 )

# Cada GPIO esta abstraido pelo kernel como um arquivo
GPIO_248="$GPIO_DIR/gpio248"
GPIO_249="$GPIO_DIR/gpio249"
GPIO_250="$GPIO_DIR/gpio250"
GPIO_251="$GPIO_DIR/gpio251"
GPIO_252="$GPIO_DIR/gpio252"
GPIO_253="$GPIO_DIR/gpio253"
GPIO_254="$GPIO_DIR/gpio254"
GPIO_255="$GPIO_DIR/gpio255"

function export_gpios {
  # Usage: export_gpios
  # Esta funcao exporta os gpios do grupo GPIOS e define
  # duas propriedades "direction" para OUT.
  for gpio in ${GPIOS[@]}; do
    gpio_file="${!gpio}"
    if [ ! -f $gpio_file ]; then
      gpio_num="${gpio#*_}"
      echo $gpio_num >$GPIO_DIR/export
    fi
    # Ajusta gpio para ser do tipo OUT
    echo "out" >$gpio_file/direction
    if [ $? -ne "0" ]; then
      echo "Erro exportando $gpio" >&2
      exit 1
    fi
  done
}

function unexport_gpios {
  # Usage: unexport_gpios
  # Esta funcao remove os GPIOs exportados.
  for gpio in ${GPIOS[@]}; do
    gpio_num="${gpio#*_}"
    echo $gpio_num >$GPIO_DIR/unexport
  done
}

function lcd_device_write {
  # Usage: lcd_device_write_bin bit_7 bit_6 bit_5 bit_4 bit_3 bit_2 bit_1 bit_0
  for bit in `seq 0 7`; do
    pos=$((bit+1))
    echo ${!pos} >${!GPIOS[bit]}/value
  done
}

function convert_lcd_activate {
  # Usage: convert_lcd_activate <command>
  # O bit 6 eh o bit EN (Enable)
  echo "$(($1|1<<6))"
}

function convert_lcd_backlight_on {
  # Usage: convert_lcd_backlight_on <command>
  # O bit 7 e o bit BACKLIGHT, que aqui ficara sempre ON
  echo "$(($1|1<<7))"
}

function convert_to_bin {
  # Usage: convert_to_bin <number_to_be_converted>
  # Essa funcao converte e reagrupa um numero de 8 bits (qualquer) em formato
  # binario, separado por espacos, e reagrupados no formato: "4-lsb 4-msb"
  H_0="0 0 0 0"
  H_1="0 0 0 1"
  H_2="0 0 1 0"
  H_3="0 0 1 1"
  H_4="0 1 0 0"
  H_5="0 1 0 1"
  H_6="0 1 1 0"
  H_7="0 1 1 1"
  H_8="1 0 0 0"
  H_9="1 0 0 1"
  H_A="1 0 1 0"
  H_B="1 0 1 1"
  H_C="1 1 0 0"
  H_D="1 1 0 1"
  H_E="1 1 1 0"
  H_F="1 1 1 1"
  i=$(($1 & 0xFF)) # Apenas os ultimos 8 bits
  hex=$(printf %02X $i)
  p1="H_${hex:0:1}"
  p2="H_${hex:1:1}"
  echo "${!p2} ${!p1}" # Reagrupa os bits para este LCD
}

function lcd_write {
  # Usage: lcd_write cmd_1 cmd_2 ... cmd_n
  for command in $@; do
    back_en="$(convert_lcd_backlight_on $command)"
    strobe="$(convert_lcd_activate $back_en)"

    # Envia a informacao
    bin="$(convert_to_bin $back_en)"
    lcd_device_write $bin

    # Habilita o bit de ativacao e reenvia
    bin="$(convert_to_bin $strobe)"
    lcd_device_write $bin

    # Reenvia a informacao para posterior leitura
    bin="$(convert_to_bin $back_en)"
    lcd_device_write $bin
  done
}

function lcd_initialize {
  # Usage: lcd_initialize
  # Procede a inicializacao do LCD.
  lcd_write 0x3
}

function lcd_setup {
  # Usage: lcd_setup
  # Envia os parametros de configuracao do LCD.
  lcd_write 0x2 0x8 0x0 # 4 bits e modo multiline
  lcd_write 0x0 0x8 # Ocultar cursor
  lcd_write 0x0 0x1 # Move cursor para posicao HOME
  lcd_write 0x0 0x6 # Move cursor para a direita
  lcd_write 0x0 0xC # Liga o display
}

function lcd_display_char {
  # Usage: lcd_display_char <char>
  # Esta funcao exibe um caractere no LCD.
  cval=$(LC_CTYPE=C printf '%d' "'$1")
  p1=$((1<<4|cval>>4))
  p2=$((1<<4|cval&0x0F))
  lcd_write $p1 $p2 0x0
}

function lcd_display_text {
  # Usage: lcd_display_text <text> <line>
  # Esta funcao exibe um texto no LCD, na linha indicada.
  if [ "$2" -eq "2" ]; then
    lcd_write 0xC 0x0 # Linha 2
  else
    lcd_write 0x8 0x0 # Linha 1, default
  fi

  for c in `echo $1 |grep -o .`; do
    lcd_display_char "$c"
  done
}

# Rotinas de teste:
lcd_initialize
lcd_setup
lcd_display_text "Hello," 1
lcd_display_text "Inatel" 2

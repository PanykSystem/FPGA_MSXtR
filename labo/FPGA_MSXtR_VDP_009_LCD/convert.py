from __future__ import annotations

import argparse
from pathlib import Path


DEFAULT_INPUT = Path(__file__).resolve().parent / "impl" / "pnr" / "tangnano20k_vdp_cartridge_lcd.fs"
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "fpga_design.bin"


def convert_bitstream(input_path: Path, output_path: Path) -> int:
	byte_count = 0
	with input_path.open("r", encoding="utf-8", newline="") as input_file, output_path.open("wb") as output_file:
		for line_number, raw_line in enumerate(input_file, start=1):
			line = raw_line.strip()
			if not line or line.startswith("//"):
				continue
			if any(bit not in "01" for bit in line):
				raise ValueError(f"line {line_number}: invalid character found")
			if len(line) % 8 != 0:
				raise ValueError(f"line {line_number}: bit length is not a multiple of 8")
			for index in range(0, len(line), 8):
				byte_text = line[index:index + 8]
				output_file.write(bytes([int(byte_text, 2)]))
				byte_count += 1
	return byte_count


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Convert a Gowin .fs bitstream text file into fpga_design.bin")
	parser.add_argument("input", nargs="?", type=Path, default=DEFAULT_INPUT, help="input .fs file")
	parser.add_argument("output", nargs="?", type=Path, default=DEFAULT_OUTPUT, help="output binary file")
	return parser.parse_args()


def main() -> int:
	args = parse_args()
	byte_count = convert_bitstream(args.input, args.output)
	print(f"wrote {byte_count} bytes to {args.output}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())

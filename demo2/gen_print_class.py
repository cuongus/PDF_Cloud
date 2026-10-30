"""Sinh ZCL_DEMO_ADS_PNK_PRINT: chèn XDP (zdemo_pnk.xdp) thành chuỗi ABAP."""
import pathlib

here = pathlib.Path(__file__).parent
xdp_lines = [l.strip() for l in (here / "zdemo_pnk.xdp").read_text(encoding="utf-8").splitlines() if l.strip()]

chunks = []
for line in xdp_lines:
    while len(line) > 180:
        cut = line.rfind("><", 0, 180) + 1
        if cut <= 0:
            cut = 180
        chunks.append(line[:cut])
        line = line[cut:]
    chunks.append(line)

assert all("`" not in c for c in chunks)
xdp_abap = " &&\n".join(f"      `{c}`" for c in chunks)

template = (here / "zcl_demo_ads_pnk_print.tpl.abap").read_text(encoding="utf-8")
out = template.replace("      `__XDP__`", xdp_abap)
(here / "src" / "zcl_demo_ads_pnk_print.clas.abap").write_text(out, encoding="utf-8", newline="\n")
print(len(chunks), "dòng XDP,", max(len(c) for c in chunks), "ký tự dài nhất")

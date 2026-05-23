import argparse
import os
import queue
import threading
import time
import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext, ttk

import serial
from serial.tools import list_ports
from PIL import Image, ImageTk

try:
    from tkinterdnd2 import DND_FILES, TkinterDnD
    HAS_DND = True
except Exception:
    DND_FILES = None
    TkinterDnD = None
    HAS_DND = False


WIDTH = 320
HEIGHT = 240
BAUD = 115200
HEADER = 0xAA
PACKET_DATA_SIZE = 256
ACK = 0x06
NACK = 0x15
MAX_RETRY = 10
ACK_TIMEOUT = 5.0
RETRY_DELAY = 0.3


def log_print(message):
    print(message, flush=True)


def rgb888_to_rgb565(r, g, b):
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)


def crc8(data: bytes, init_crc=0xFF):
    crc = init_crc
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x80:
                crc = ((crc << 1) & 0xFF) ^ 0x07
            else:
                crc = (crc << 1) & 0xFF
    return crc & 0xFF


def image_to_rgb565_bytes(img):
    raw = bytearray()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            r, g, b = img.getpixel((x, y))
            rgb565 = rgb888_to_rgb565(r, g, b)
            raw.append((rgb565 >> 8) & 0xFF)
            raw.append(rgb565 & 0xFF)
    return raw


def load_image_bytes(path):
    img = Image.open(path).convert("RGB")
    img = img.resize((WIDTH, HEIGHT))
    return img, image_to_rgb565_bytes(img)


def build_packet(data_chunk: bytes):
    if len(data_chunk) != PACKET_DATA_SIZE:
        raise ValueError("Data chunk must be exactly 256 bytes")
    crc = crc8(data_chunk)
    packet = bytearray([HEADER])
    packet.extend(data_chunk)
    packet.append(crc)
    return packet, crc


def wait_ack(ser, stop_event=None):
    start = time.time()
    while (time.time() - start) < ACK_TIMEOUT:
        if stop_event is not None and stop_event.is_set():
            return None
        if ser.in_waiting > 0:
            resp = ser.read(1)
            if len(resp) == 1:
                return resp[0]
        time.sleep(0.01)
    return None


def send_packet_with_retry(ser, packet, packet_index, total_packets, log=log_print, stop_event=None):
    for attempt in range(1, MAX_RETRY + 1):
        if stop_event is not None and stop_event.is_set():
            log("[WARN] Send cancelled")
            return False

        log(
            f"[INFO] Packet {packet_index + 1}/{total_packets} "
            f"- Attempt {attempt}/{MAX_RETRY}"
        )

        ser.reset_input_buffer()
        ser.reset_output_buffer()
        ser.write(packet)
        ser.flush()

        resp = wait_ack(ser, stop_event=stop_event)

        if resp == ACK:
            log(f"[INFO] Packet {packet_index + 1}/{total_packets}: ACK")
            return True
        if resp == NACK:
            log(f"[WARN] Packet {packet_index + 1}/{total_packets}: NACK -> retry")
            time.sleep(RETRY_DELAY)
        else:
            log(f"[WARN] Packet {packet_index + 1}/{total_packets}: ACK timeout -> retry")
            time.sleep(RETRY_DELAY)

    return False


def send_image_over_serial(ser, raw_data, log=log_print, progress=None, stop_event=None):
    total_bytes = len(raw_data)
    total_packets = total_bytes // PACKET_DATA_SIZE
    start_time = time.time()

    log(f"[INFO] Total bytes   : {total_bytes}")
    log(f"[INFO] Total packets : {total_packets}")
    log(f"[INFO] Packet bytes  : {PACKET_DATA_SIZE}")

    for packet_index in range(total_packets):
        if stop_event is not None and stop_event.is_set():
            raise RuntimeError("Send cancelled")

        start = packet_index * PACKET_DATA_SIZE
        data_chunk = raw_data[start:start + PACKET_DATA_SIZE]
        packet, crc = build_packet(data_chunk)
        log(f"[INFO] Build packet {packet_index + 1}/{total_packets} (CRC8 = 0x{crc:02X})")

        ok = send_packet_with_retry(
            ser,
            packet,
            packet_index,
            total_packets,
            log=log,
            stop_event=stop_event,
        )
        if not ok:
            raise RuntimeError(f"Packet {packet_index + 1}/{total_packets} failed")

        if progress is not None:
            progress(packet_index + 1, total_packets)

    elapsed = time.time() - start_time
    throughput = total_bytes / elapsed if elapsed > 0 else 0.0
    log("[INFO] ====================================")
    log("[INFO] Transmission completed")
    log(f"[INFO] Total packets : {total_packets}")
    log(f"[INFO] Total bytes   : {total_bytes}")
    log(f"[INFO] Elapsed time  : {elapsed:.2f} s")
    log(f"[INFO] Throughput    : {throughput:.2f} B/s")
    log("[INFO] ====================================")


BaseTk = TkinterDnD.Tk if HAS_DND else tk.Tk


class ImageSenderApp(BaseTk):
    def __init__(self):
        super().__init__()
        self.title("ImageAES128 UART Loader")
        self.geometry("1180x760")
        self.minsize(1020, 640)

        self.image_path = None
        self.preview_ref = None
        self.serial_obj = None
        self.worker = None
        self.stop_event = threading.Event()
        self.ui_queue = queue.Queue()

        self.path_var = tk.StringVar(value="No image selected")
        self.port_var = tk.StringVar()
        self.baud_var = tk.IntVar(value=BAUD)
        self.status_var = tk.StringVar(value="Disconnected")
        self.packet_var = tk.StringVar(value="0 / 600 packets")
        self.progress_var = tk.DoubleVar(value=0.0)

        self._build_ui()
        self.refresh_ports()
        self.after(100, self._drain_queue)

        if HAS_DND:
            self.drop_target_register(DND_FILES)
            self.dnd_bind("<<Drop>>", self._handle_drop)
            self._log("[INFO] Drag-and-drop enabled")
        else:
            self._log("[WARN] Drag-and-drop needs tkinterdnd2; use Browse Image if it is not installed")

    def _build_ui(self):
        root = ttk.Frame(self, padding=12)
        root.pack(fill="both", expand=True)

        left = ttk.Frame(root)
        left.pack(side="left", fill="both", expand=False)

        right = ttk.Frame(root)
        right.pack(side="right", fill="both", expand=True, padx=(12, 0))

        preview_box = ttk.LabelFrame(left, text="Image Preview", padding=10)
        preview_box.pack(fill="both", expand=False)
        preview_box.configure(width=800, height=600)
        preview_box.pack_propagate(False)

        self.preview_label = ttk.Label(
            preview_box,
            text="Drop image here\nor click Browse Image",
            anchor="center",
            justify="center",
            width=66,
        )
        self.preview_label.pack(fill="both", expand=True)

        ttk.Label(left, textvariable=self.path_var, wraplength=540).pack(fill="x", pady=(8, 12))

        ttk.Button(left, text="Browse Image", command=self.browse_image).pack(fill="x")

        conn_box = ttk.LabelFrame(left, text="Connection", padding=10)
        conn_box.pack(fill="x", pady=(12, 0))

        ttk.Label(conn_box, text="COM port").grid(row=0, column=0, sticky="w")
        self.port_combo = ttk.Combobox(conn_box, textvariable=self.port_var, width=18)
        self.port_combo.grid(row=0, column=1, sticky="ew", padx=(8, 4))
        ttk.Button(conn_box, text="Refresh", command=self.refresh_ports).grid(row=0, column=2)

        ttk.Label(conn_box, text="Baud").grid(row=1, column=0, sticky="w", pady=(8, 0))
        ttk.Entry(conn_box, textvariable=self.baud_var, width=10).grid(row=1, column=1, sticky="w", padx=(8, 4), pady=(8, 0))

        self.connect_btn = ttk.Button(conn_box, text="Connect", command=self.toggle_connection)
        self.connect_btn.grid(row=2, column=0, columnspan=3, sticky="ew", pady=(10, 0))
        conn_box.columnconfigure(1, weight=1)

        action_box = ttk.LabelFrame(left, text="Transfer", padding=10)
        action_box.pack(fill="x", pady=(12, 0))

        self.send_btn = ttk.Button(action_box, text="Send Image", command=self.start_send)
        self.send_btn.pack(fill="x")
        self.cancel_btn = ttk.Button(action_box, text="Cancel", command=self.cancel_send, state="disabled")
        self.cancel_btn.pack(fill="x", pady=(8, 0))

        ttk.Progressbar(action_box, variable=self.progress_var, maximum=100.0).pack(fill="x", pady=(10, 0))
        ttk.Label(action_box, textvariable=self.packet_var).pack(anchor="w", pady=(6, 0))
        ttk.Label(action_box, textvariable=self.status_var).pack(anchor="w")

        log_box = ttk.LabelFrame(right, text="Debug Log", padding=8)
        log_box.pack(fill="both", expand=True)
        self.log_text = scrolledtext.ScrolledText(log_box, width=62, height=24, wrap="word")
        self.log_text.pack(fill="both", expand=True)

        clear_log_btn = ttk.Button(right, text="Clear Log", command=lambda: self.log_text.delete("1.0", "end"))
        clear_log_btn.pack(anchor="e", pady=(8, 0))

    def _log(self, message):
        ts = time.strftime("%H:%M:%S")
        self.log_text.insert("end", f"{ts} {message}\n")
        self.log_text.see("end")

    def _queue_log(self, message):
        self.ui_queue.put(("log", message))

    def _queue_status(self, message):
        self.ui_queue.put(("status", message))

    def _queue_progress(self, sent, total):
        self.ui_queue.put(("progress", sent, total))

    def _drain_queue(self):
        try:
            while True:
                item = self.ui_queue.get_nowait()
                if item[0] == "log":
                    self._log(item[1])
                elif item[0] == "status":
                    self.status_var.set(item[1])
                elif item[0] == "progress":
                    sent, total = item[1], item[2]
                    self.progress_var.set((sent * 100.0) / total)
                    self.packet_var.set(f"{sent} / {total} packets")
                elif item[0] == "done":
                    self._transfer_done(item[1])
        except queue.Empty:
            pass
        self.after(100, self._drain_queue)

    def refresh_ports(self):
        ports = [p.device for p in list_ports.comports()]
        self.port_combo["values"] = ports
        if ports and not self.port_var.get():
            self.port_var.set(ports[0])
        self._log(f"[INFO] Ports: {', '.join(ports) if ports else 'none'}")

    def browse_image(self):
        path = filedialog.askopenfilename(
            title="Select image",
            filetypes=[
                ("Images", "*.png *.jpg *.jpeg *.bmp *.gif"),
                ("All files", "*.*"),
            ],
        )
        if path:
            self.load_preview(path)

    def _handle_drop(self, event):
        paths = self.tk.splitlist(event.data)
        if paths:
            self.load_preview(paths[0])

    def load_preview(self, path):
        try:
            img = Image.open(path).convert("RGB")
            img.thumbnail((540, 405))
            self.preview_ref = ImageTk.PhotoImage(img)
            self.preview_label.configure(image=self.preview_ref, text="")
            self.image_path = path
            self.path_var.set(path)
            self._log(f"[INFO] Image selected: {path}")
        except Exception as exc:
            messagebox.showerror("Image error", str(exc))
            self._log(f"[ERROR] Image load failed: {exc}")

    def toggle_connection(self):
        if self.serial_obj and self.serial_obj.is_open:
            self.serial_obj.close()
            self.serial_obj = None
            self.status_var.set("Disconnected")
            self.connect_btn.configure(text="Connect")
            self._log("[INFO] UART disconnected")
            return

        port = self.port_var.get().strip()
        if not port:
            messagebox.showwarning("Missing port", "Select or type a COM port first")
            return

        try:
            self.serial_obj = serial.Serial(
                port=port,
                baudrate=int(self.baud_var.get()),
                timeout=0.1,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
            )
            self.status_var.set(f"Connected: {port} @ {self.baud_var.get()}")
            self.connect_btn.configure(text="Disconnect")
            self._log(f"[INFO] UART connected: {port} @ {self.baud_var.get()}")
        except Exception as exc:
            self.serial_obj = None
            messagebox.showerror("Connection error", str(exc))
            self._log(f"[ERROR] UART connection failed: {exc}")

    def start_send(self):
        if self.worker and self.worker.is_alive():
            return
        if not self.image_path:
            messagebox.showwarning("Missing image", "Select an image first")
            return
        if not self.serial_obj or not self.serial_obj.is_open:
            self.toggle_connection()
        if not self.serial_obj or not self.serial_obj.is_open:
            return

        self.stop_event.clear()
        self.progress_var.set(0)
        self.packet_var.set("0 / 600 packets")
        self.send_btn.configure(state="disabled")
        self.cancel_btn.configure(state="normal")
        self._queue_status("Preparing image")

        self.worker = threading.Thread(target=self._send_worker, daemon=True)
        self.worker.start()

    def cancel_send(self):
        self.stop_event.set()
        self._log("[WARN] Cancel requested")

    def _send_worker(self):
        ok = False
        try:
            self._queue_log(f"[INFO] Opening image: {self.image_path}")
            _, raw_data = load_image_bytes(self.image_path)
            self._queue_status("Sending image")
            send_image_over_serial(
                self.serial_obj,
                raw_data,
                log=self._queue_log,
                progress=self._queue_progress,
                stop_event=self.stop_event,
            )
            ok = True
            self._queue_status("Transfer completed")
        except Exception as exc:
            self._queue_log(f"[ERROR] {exc}")
            self._queue_status("Transfer failed")
        finally:
            self.ui_queue.put(("done", ok))

    def _transfer_done(self, ok):
        self.send_btn.configure(state="normal")
        self.cancel_btn.configure(state="disabled")
        if ok:
            self._log("[INFO] Ready: press KEY1 on FPGA after dashboard shows image loaded")


def run_cli(path, port, baud):
    log_print(f"[INFO] Opening image: {path}")
    _, raw_data = load_image_bytes(path)
    ser = serial.Serial(
        port=port,
        baudrate=baud,
        timeout=0.1,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
    )
    try:
        log_print(f"[INFO] UART opened : {port}")
        log_print(f"[INFO] Baudrate    : {baud}")
        send_image_over_serial(ser, raw_data)
    finally:
        ser.close()


def main():
    parser = argparse.ArgumentParser(description="UART image sender with GUI/CLI debug")
    parser.add_argument("--path", help="Image path")
    parser.add_argument("--port", help="UART port, for example COM3")
    parser.add_argument("--baud", type=int, default=BAUD, help="UART baudrate")
    parser.add_argument("--gui", action="store_true", help="Launch Tkinter GUI")
    args = parser.parse_args()

    if args.gui or not (args.path and args.port):
        app = ImageSenderApp()
        if args.path and os.path.exists(args.path):
            app.load_preview(args.path)
        if args.port:
            app.port_var.set(args.port)
        app.mainloop()
    else:
        run_cli(args.path, args.port, args.baud)


if __name__ == "__main__":
    main()

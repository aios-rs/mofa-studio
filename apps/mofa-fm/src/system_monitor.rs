//! Background system monitor for CPU and memory usage
//!
//! This module provides a thread-safe system monitor that polls CPU and memory
//! usage in a background thread, keeping the UI thread free.

use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::{Arc, OnceLock};
use std::thread;
use std::time::Duration;
use sysinfo::System;

/// Shared system stats, updated by background thread
struct SystemStats {
    /// CPU usage scaled to 0-10000 (representing 0.00% to 100.00%)
    cpu_usage: AtomicU32,
    /// Memory usage scaled to 0-10000 (representing 0.00% to 100.00%)
    memory_usage: AtomicU32,
}

impl SystemStats {
    fn new() -> Self {
        Self {
            cpu_usage: AtomicU32::new(0),
            memory_usage: AtomicU32::new(0),
        }
    }
}

/// Global system monitor instance
static SYSTEM_MONITOR: OnceLock<Arc<SystemStats>> = OnceLock::new();

/// Start the background system monitor thread if not already running.
/// This should be called once at app startup.
pub fn start_system_monitor() {
    SYSTEM_MONITOR.get_or_init(|| {
        let stats = Arc::new(SystemStats::new());
        let stats_clone = Arc::clone(&stats);

        thread::Builder::new()
            .name("system-monitor".to_string())
            .spawn(move || {
                let mut sys = System::new_all();

                loop {
                    // Refresh CPU and memory
                    sys.refresh_cpu_usage();
                    sys.refresh_memory();

                    // Get CPU usage (0.0 - 100.0)
                    let cpu = sys.global_cpu_usage();
                    let cpu_scaled = (cpu * 100.0) as u32; // Scale to 0-10000
                    stats_clone.cpu_usage.store(cpu_scaled, Ordering::Relaxed);

                    // Get memory usage
                    let total_memory = sys.total_memory();
                    let used_memory = sys.used_memory();
                    let memory_pct = if total_memory > 0 {
                        (used_memory as f64 / total_memory as f64 * 10000.0) as u32
                    } else {
                        0
                    };
                    stats_clone.memory_usage.store(memory_pct, Ordering::Relaxed);

                    // Sleep for 1 second
                    thread::sleep(Duration::from_secs(1));
                }
            })
            .expect("Failed to spawn system monitor thread");

        stats
    });
}

/// Get current CPU usage as a value between 0.0 and 1.0
pub fn get_cpu_usage() -> f64 {
    SYSTEM_MONITOR
        .get()
        .map(|stats| stats.cpu_usage.load(Ordering::Relaxed) as f64 / 10000.0)
        .unwrap_or(0.0)
}

/// Get current memory usage as a value between 0.0 and 1.0
pub fn get_memory_usage() -> f64 {
    SYSTEM_MONITOR
        .get()
        .map(|stats| stats.memory_usage.load(Ordering::Relaxed) as f64 / 10000.0)
        .unwrap_or(0.0)
}

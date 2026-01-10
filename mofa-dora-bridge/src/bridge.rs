//! DoraBridge trait and common bridge functionality

use crate::data::DoraData;
use crate::error::BridgeResult;

/// Bridge connection state
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BridgeState {
    /// Bridge is disconnected
    Disconnected,
    /// Bridge is connecting
    Connecting,
    /// Bridge is connected and ready
    Connected,
    /// Bridge is disconnecting
    Disconnecting,
    /// Bridge encountered an error
    Error,
}

impl Default for BridgeState {
    fn default() -> Self {
        BridgeState::Disconnected
    }
}

/// Core trait for all dora bridges
///
/// Each widget implements this trait to connect as a dynamic node.
/// Status updates (connected/disconnected/error) are communicated via SharedDoraState.
/// Data (audio/chat/logs) is pushed directly to SharedDoraState for UI consumption.
pub trait DoraBridge: Send + Sync {
    /// Get the node ID for this bridge (e.g., "mofa-audio-player")
    fn node_id(&self) -> &str;

    /// Get current connection state
    fn state(&self) -> BridgeState;

    /// Connect to the dora dataflow as a dynamic node
    fn connect(&mut self) -> BridgeResult<()>;

    /// Disconnect from dora
    fn disconnect(&mut self) -> BridgeResult<()>;

    /// Check if connected
    fn is_connected(&self) -> bool {
        self.state() == BridgeState::Connected
    }

    /// Send data to a dora output
    fn send(&self, output_id: &str, data: DoraData) -> BridgeResult<()>;

    /// Get list of input IDs this bridge expects
    fn expected_inputs(&self) -> Vec<String>;

    /// Get list of output IDs this bridge provides
    fn expected_outputs(&self) -> Vec<String>;
}

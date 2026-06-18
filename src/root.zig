//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
pub const utils = @import("utils.zig");
pub const datamodel = @import("datamodel.zig");
pub const diskops = @import("diskops/serialize.zig");

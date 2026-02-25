use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::Path;

use rayon::prelude::*;
use devcap_core::{discovery, git, model, period};

/// Scan repositories and return results as a JSON string.
///
/// # Safety
/// - `path_ptr` must be a valid null-terminated UTF-8 string.
/// - `period_ptr` must be a valid null-terminated UTF-8 string.
/// - `author_ptr` may be null; if non-null it must be a valid null-terminated UTF-8 string.
/// - The caller must free the returned pointer with `devcap_free_string`.
#[no_mangle]
pub unsafe extern "C" fn devcap_scan(
    path_ptr: *const c_char,
    period_ptr: *const c_char,
    author_ptr: *const c_char,
) -> *mut c_char {
    let result = scan_inner(path_ptr, period_ptr, author_ptr);
    match CString::new(result) {
        Ok(s) => s.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

unsafe fn scan_inner(
    path_ptr: *const c_char,
    period_ptr: *const c_char,
    author_ptr: *const c_char,
) -> String {
    let path_str = match unsafe { CStr::from_ptr(path_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return "[]".to_string(),
    };

    let period_str = match unsafe { CStr::from_ptr(period_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return "[]".to_string(),
    };

    let author = if author_ptr.is_null() {
        git::default_author()
    } else {
        match unsafe { CStr::from_ptr(author_ptr) }.to_str() {
            Ok(s) if !s.is_empty() => Some(s.to_string()),
            _ => git::default_author(),
        }
    };

    let period: period::Period = match period_str.parse() {
        Ok(p) => p,
        Err(_) => return "[]".to_string(),
    };

    let range = period.to_time_range();
    let repos = discovery::find_repos(Path::new(path_str));

    let mut projects: Vec<model::ProjectLog> = repos
        .par_iter()
        .filter_map(|repo| git::collect_project_log(repo, &range, author.as_deref()))
        .collect();

    projects.sort_by(|a, b| {
        let latest = |p: &model::ProjectLog| {
            p.branches
                .iter()
                .flat_map(|br| br.commits.first())
                .map(|c| c.time)
                .max()
        };
        latest(b).cmp(&latest(a))
    });

    serde_json::to_string(&projects).unwrap_or_else(|_| "[]".to_string())
}

/// Get the default git author name.
///
/// # Safety
/// The caller must free the returned pointer with `devcap_free_string`.
/// Returns null if no author is configured.
#[no_mangle]
pub extern "C" fn devcap_default_author() -> *mut c_char {
    match git::default_author() {
        Some(name) => match CString::new(name) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        None => std::ptr::null_mut(),
    }
}

/// Free a string previously returned by `devcap_scan` or `devcap_default_author`.
///
/// # Safety
/// `ptr` must be a pointer previously returned by this library, or null.
#[no_mangle]
pub unsafe extern "C" fn devcap_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}

"""
HDF5 I/O utilities with robust file locking for parallel processing.

This module provides retry logic for HDF5 file operations to handle
concurrent access from multiple processes gracefully.
"""

import h5py
import time
import random
import logging
from typing import Optional

logger = logging.getLogger(__name__)


def open_hdf5_with_retry(
    filepath: str,
    mode: str,
    max_retries: int = 10,
    base_delay: float = 0.5,
    max_delay: float = 30.0
) -> h5py.File:
    """
    Open HDF5 file with exponential backoff retry logic for file locking conflicts.
    
    This function handles the common case where multiple parallel processes try to
    write to the same HDF5 file simultaneously, which causes file locking errors
    (errno 11: Resource temporarily unavailable).
    
    Parameters
    ----------
    filepath : str
        Path to the HDF5 file
    mode : str
        File access mode ('r', 'r+', 'w', 'a')
    max_retries : int, optional
        Maximum number of retry attempts (default: 10)
    base_delay : float, optional
        Initial delay between retries in seconds (default: 0.5)
    max_delay : float, optional
        Maximum delay between retries in seconds (default: 30.0)
    
    Returns
    -------
    h5py.File
        Opened HDF5 file handle
    
    Raises
    ------
    OSError
        If file cannot be opened after max_retries attempts
    BlockingIOError
        If file locking fails after max_retries attempts
    
    Examples
    --------
    >>> f = open_hdf5_with_retry("data.hdf5", "r+")
    >>> with f:
    ...     f['dataset'][:] = new_data
    
    Notes
    -----
    - Uses exponential backoff with jitter to avoid thundering herd problem
    - Safe for parallel processing with SLURM or other batch systems
    - Logs retry attempts for debugging
    """
    for attempt in range(max_retries):
        try:
            # Attempt to open the file
            f = h5py.File(filepath, mode)
            
            # Log successful open after retry
            if attempt > 0:
                logger.info(f"Successfully opened {filepath} after {attempt} retry attempts")
            
            return f
            
        except (OSError, BlockingIOError) as e:
            # Check if this is a file locking error
            if "unable to lock file" in str(e).lower() or e.errno == 11:
                if attempt < max_retries - 1:
                    # Calculate exponential backoff delay with jitter
                    delay = min(
                        base_delay * (2 ** attempt) + random.uniform(0, 1),
                        max_delay
                    )
                    
                    logger.warning(
                        f"HDF5 file lock conflict on {filepath} "
                        f"(attempt {attempt + 1}/{max_retries}). "
                        f"Retrying in {delay:.2f}s..."
                    )
                    
                    time.sleep(delay)
                else:
                    # Final attempt failed
                    logger.error(
                        f"Failed to open {filepath} after {max_retries} attempts. "
                        f"File may be locked by another process."
                    )
                    raise OSError(
                        f"Unable to open HDF5 file {filepath} after {max_retries} attempts. "
                        f"The file is locked by another process. "
                        f"This typically happens when multiple jobs write to the same file "
                        f"simultaneously. Try: 1) Stagger job submissions by 1-2 minutes, or "
                        f"2) Wait for other jobs to complete preprocessing."
                    ) from e
            else:
                # Not a locking error, re-raise immediately
                raise


def safe_hdf5_write(filepath: str, mode: str, write_function, *args, **kwargs):
    """
    Safely write to HDF5 file with retry logic and automatic cleanup.
    
    This is a convenience wrapper that handles opening, writing, and closing
    the HDF5 file with proper retry logic and error handling.
    
    Parameters
    ----------
    filepath : str
        Path to the HDF5 file
    mode : str
        File access mode ('r+', 'a')
    write_function : callable
        Function that performs the write operation. Should accept h5py.File as first argument.
    *args
        Additional positional arguments to pass to write_function
    **kwargs
        Additional keyword arguments to pass to write_function
    
    Returns
    -------
    Any
        Return value from write_function
    
    Examples
    --------
    >>> def write_data(f, dataset_name, data):
    ...     f[dataset_name][:] = data
    >>> 
    >>> safe_hdf5_write("data.hdf5", "r+", write_data, "mydata", new_values)
    """
    f = None
    try:
        f = open_hdf5_with_retry(filepath, mode)
        result = write_function(f, *args, **kwargs)
        return result
    finally:
        if f is not None:
            f.close()


def check_hdf5_lock_support():
    """
    Check if the HDF5 library supports file locking.
    
    Returns
    -------
    bool
        True if file locking is supported
    """
    try:
        import h5py
        # Check HDF5 version - file locking improved significantly in 1.10+
        version = h5py.version.hdf5_version_tuple
        if version >= (1, 10, 0):
            logger.info(f"HDF5 version {h5py.version.hdf5_version} supports file locking")
            return True
        else:
            logger.warning(
                f"HDF5 version {h5py.version.hdf5_version} may have limited file locking support. "
                f"Consider upgrading to HDF5 1.10+ for better parallel processing."
            )
            return False
    except Exception as e:
        logger.error(f"Failed to check HDF5 version: {e}")
        return False

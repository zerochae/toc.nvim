toc.nvim rst demo
=================

Introduction
------------

reStructuredText sections are defined by an underline; the order in which each
adornment character first appears sets the level.

Motivation
~~~~~~~~~~

Why an outline helps while editing long documents.

Usage
-----

Configuration
~~~~~~~~~~~~~~

.. code-block:: lua

   require("toc").setup {
     preset = "compact",
   }

See `the repository <https://github.com/zerochae/toc.nvim>`_ for the full
option list.

Reference
---------

Because levels follow first-appearance order, ``=`` is level 1, ``-`` level 2,
and ``~`` level 3 in this document.

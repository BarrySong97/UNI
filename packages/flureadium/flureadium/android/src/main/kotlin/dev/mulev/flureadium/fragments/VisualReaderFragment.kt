package dev.mulev.flureadium.fragments

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import dev.mulev.flureadium.databinding.FragmentReaderBinding
import dev.mulev.flureadium.viewLifecycle

private const val TAG = "VisualReaderFragment"

abstract class VisualReaderFragment : BaseReaderFragment() {
    private var binding: FragmentReaderBinding by viewLifecycle()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        Log.d(TAG, "::onCreateView")
        binding = FragmentReaderBinding.inflate(inflater, container, false)

        return binding.root
    }
}

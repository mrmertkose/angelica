<script setup>
defineProps({
    type: {
        type: String,
        default: 'submit',
    },
});
</script>

<template>
    <button :type="type" class="inline-flex justify-center items-center px-4 py-2 bg-gray-800 border border-transparent rounded-lg text-sm font-semibold text-white tracking-widest hover:bg-gray-700 focus:bg-gray-700 active:bg-gray-900 focus:outline-none focus:ring-0 focus:ring-offset-0 transition ease-in-out duration-150 disabled:opacity-25">
        <slot />
    </button>
</template>

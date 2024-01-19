<template>
    <div class="min-h-screen flex flex-col sm:justify-center items-center pt-6 sm:pt-0 bg-gray-100">
        <div>
            <slot name="logo" />
        </div>

        <div class="w-3/4 md:w-1/4 mt-6 px-6 py-4 bg-white shadow-md rounded-lg">
            <slot />
        </div>
    </div>
</template>

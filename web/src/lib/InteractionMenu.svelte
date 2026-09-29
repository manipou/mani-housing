<script lang="ts">
    import { visibilityStore as visibility, House, NearbyPlayers, Current, Locales, Props } from "$lib/stores/VisibilityStore";
    import { fetchNui } from "$lib/utils/fetchNui";
    import SelectPlayer from "./components/SelectPlayer.svelte";
    import Input from "./components/Input.svelte";

    let expanded = $state({});
    let editingPermissions = $state({});
    let showSelectPlayer = $state(false);
    let showStashPinInput = $state(false);

    function toggleExpanded(identifier: string, data: any) {
        if (!expanded[identifier]) {
            editingPermissions[identifier] = {
                Enter: data.Permissions.Enter,
                Garage: data.Permissions.Garage,
                Stash: data.Permissions.Stash,
                Admin: data.Permissions.Admin
            };
        }
        expanded[identifier] = !expanded[identifier];
    }

    function savePermissions(identifier: string) {
        const perms = editingPermissions[identifier]
        fetchNui("UpdateKeyPermissions", {
            HouseId: $House.HouseId,
            Identifier: identifier,
            Permissions: perms
        });
        $House.Keyholders[identifier].Permissions = { ...perms };
        delete editingPermissions[identifier];
        expanded[identifier] = false;
    }

    function removeKeyholder(identifier: string) {
        fetchNui('RemoveKeyholder', {
            HouseId: $House.HouseId,
            Identifier: identifier
        }).then(Data => {
            if (Data.Success) {
                const newKeyholders = { ...$House.Keyholders };
                delete newKeyholders[identifier];
                House.set({ ...$House, Keyholders: newKeyholders });

                if (expanded[identifier]) {
                    delete editingPermissions[identifier];
                    expanded[identifier] = false;
                }
            }
        })
    }

    function addKeyholder() {
        fetchNui('GetNearbyPlayers').then(Data => {
            NearbyPlayers.set(Data)
            showSelectPlayer = true;
        })
    }

    function placeWardrobe() {
        fetchNui("PlaceWardrobe");
        Current.set("guide");
    }

    function placeStash() {
        fetchNui("PlaceStash");
        Current.set("guide");
    }

    function setStashPin() {
        showStashPinInput = true;
    }

    function handleStashPinConfirm(e: CustomEvent) {
        showStashPinInput = false;
        if (e.detail == null) return;

        fetchNui("SetStashPin", {
            HouseId: $House.HouseId,
            Pin: e.detail
        }).then(Data => {
            if (Data.Success) {
                $House.HasStashPin = true;
            }
        });
    }

    function startDecorating() {
        fetchNui('StartDecorating').then(Data => {
            if (Data.Success) {
                Current.set("decor");
                Props.set(Data.Decorations);
            }
        })
    }

    function CloseUI() {
        fetchNui("HideUI");
        visibility.hide();
    }

    function GiveKey(event: CustomEvent) {
        fetchNui('GiveKeys', event.detail).then(Data => {
            if (Data.Success) {
                $House.Keyholders = Data.Keyholders
            }
        })
        showSelectPlayer = false;
    }
    
    function CloseModal() {
        showSelectPlayer = false;
    }
</script>

<div class="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50 select-none">
    <div class="w-[1000px] h-[700px] bg-[#121212] rounded-lg shadow-2xl flex flex-col overflow-hidden border border-[#333333]">
        <header class="bg-[#1a1a1a] border-b border-[#333333] px-4 py-3 flex justify-between items-center">
            <div class="flex items-center">
                <h1 class="text-white font-medium mr-2">{$House.Coords?.Zone ?? "Unknown Zone"}:</h1>
                <h1 class="text-blue-400 font-medium">{$House.HouseId}</h1>
            </div>
            <div class="flex items-center gap-4">
                <button onclick={CloseUI} class="text-gray-400 hover:text-white transition-colors">
                    <i class="fas fa-times"></i>
                </button>
            </div>
        </header>

        <main class="flex-1 p-6 overflow-y-auto hide-scrollbar flex flex-row space-x-6">
            <!-- Keyholders Section (Left) -->
            <div class="flex-1 bg-[#1a1a1a] rounded-lg border border-[#333333] p-4 flex flex-col">
                <div class="flex items-center justify-between mb-4">
                    <h2 class="text-white font-semibold text-lg flex items-center">
                        <i class="fas fa-users text-yellow-400 mr-2"></i>
                        {$Locales["UI.Keyholders"]}
                    </h2>
                    <div class="flex items-center gap-2">
                        <span class="text-gray-400 text-sm">({Object.keys($House.Keyholders ?? {}).length})</span>
                        <button onclick={addKeyholder} class="text-blue-400 hover:text-blue-300 text-sm font-medium transition-colors">
                            + {$Locales["UI.Add"]}
                        </button>
                    </div>
                </div>
                <div class="flex-1 overflow-y-auto space-y-3">
                    {#if $House.Keyholders && Object.keys($House.Keyholders).length > 0}
                        {#each Object.entries($House.Keyholders) as [identifier, data]}
                            <div class="bg-[#1e1e1e] rounded-md border border-[#333333] overflow-hidden transition-all duration-200 hover:shadow-md hover:border-blue-400/50">
                                <!-- Main Card -->
                                <div 
                                    class="p-3 cursor-pointer flex items-center justify-between hover:bg-[#2a2a2a] transition-colors" 
                                    onclick={() => toggleExpanded(identifier, data)}
                                >
                                    <div class="flex items-center gap-3 flex-1">
                                        <div class="w-8 h-8 bg-blue-400/10 rounded-full flex items-center justify-center flex-shrink-0">
                                            <i class="fas fa-user text-blue-400"></i>
                                        </div>
                                        <div class="min-w-0 flex-1">
                                            <p class="text-white font-medium truncate text-sm">{data.Character}</p>
                                        </div>
                                    </div>
                                    <div class="flex items-center gap-2 ml-2 flex-shrink-0">
                                        <button onclick={(e) => { e.stopPropagation(); removeKeyholder(identifier); }} class="text-red-400 hover:text-red-300 p-1 transition-colors" title="Remove Keyholder">
                                            <i class="fas fa-trash"></i>
                                        </button>
                                        <i class="fas fa-chevron-down text-gray-400 transition-transform duration-200" style:transform={expanded[identifier] ? 'rotate(180deg)' : 'rotate(0deg)'}></i>
                                    </div>
                                </div>
                                
                                <!-- Dropdown/Expanded Section -->
                                {#if expanded[identifier]}
                                    <div class="bg-[#2a2a2a] px-3 py-2 border-t border-[#333333] space-y-3">
                                        <div class="space-y-2">
                                            <div class="flex items-center justify-between">
                                                <label class="text-gray-300 text-xs flex items-center gap-1">
                                                    <i class="fas fa-door-open text-gray-400 w-3 h-3"></i>
                                                    {$Locales["UI.Enter"]}
                                                </label>
                                                <div class="relative flex items-center">
                                                    <input type="checkbox" bind:checked={editingPermissions[identifier].Enter} id="enter-{identifier}" class="sr-only peer" />
                                                    <label for="enter-{identifier}" class="relative flex items-center cursor-pointer">
                                                        <div class="w-4 h-4 bg-[#1e1e1e] border-2 border-[#333333] rounded peer-checked:bg-blue-400 peer-focus:ring-2 peer-focus:ring-blue-400 transition-all duration-200 peer-checked:border-blue-400"></div>
                                                        <div class="absolute inset-0 w-4 h-4 flex items-center justify-center pointer-events-none">
                                                            {#if editingPermissions[identifier].Enter}
                                                                <svg class="w-2.5 h-2.5 text-white" fill="currentColor" viewBox="0 0 20 20">
                                                                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
                                                                </svg>
                                                            {/if}
                                                        </div>
                                                    </label>
                                                </div>
                                            </div>

                                            <div class="flex items-center justify-between">
                                                <label class="text-gray-300 text-xs flex items-center gap-1">
                                                    <i class="fas fa-car text-gray-400 w-3 h-3"></i>
                                                    {$Locales["UI.Garage"]}
                                                </label>
                                                <div class="relative flex items-center">
                                                    <input type="checkbox" bind:checked={editingPermissions[identifier].Garage} id="garage-{identifier}" class="sr-only peer" />
                                                    <label for="garage-{identifier}" class="relative flex items-center cursor-pointer">
                                                        <div class="w-4 h-4 bg-[#1e1e1e] border-2 border-[#333333] rounded peer-checked:bg-blue-400 peer-focus:ring-2 peer-focus:ring-blue-400 transition-all duration-200 peer-checked:border-blue-400"></div>
                                                        <div class="absolute inset-0 w-4 h-4 flex items-center justify-center pointer-events-none">
                                                            {#if editingPermissions[identifier].Garage}
                                                                <svg class="w-2.5 h-2.5 text-white" fill="currentColor" viewBox="0 0 20 20">
                                                                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
                                                                </svg>
                                                            {/if}
                                                        </div>
                                                    </label>
                                                </div>
                                            </div>

                                            <div class="flex items-center justify-between">
                                                <label class="text-gray-300 text-xs flex items-center gap-1">
                                                    <i class="fas fa-box-archive text-gray-400 w-3 h-3"></i>
                                                    {$Locales["UI.Stash"]}
                                                </label>
                                                <div class="relative flex items-center">
                                                    <input type="checkbox" bind:checked={editingPermissions[identifier].Stash} id="stash-{identifier}" class="sr-only peer" />
                                                    <label for="stash-{identifier}" class="relative flex items-center cursor-pointer">
                                                        <div class="w-4 h-4 bg-[#1e1e1e] border-2 border-[#333333] rounded peer-checked:bg-blue-400 peer-focus:ring-2 peer-focus:ring-blue-400 transition-all duration-200 peer-checked:border-blue-400"></div>
                                                        <div class="absolute inset-0 w-4 h-4 flex items-center justify-center pointer-events-none">
                                                            {#if editingPermissions[identifier].Stash}
                                                                <svg class="w-2.5 h-2.5 text-white" fill="currentColor" viewBox="0 0 20 20">
                                                                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
                                                                </svg>
                                                            {/if}
                                                        </div>
                                                    </label>
                                                </div>
                                            </div>

                                            <div class="flex items-center justify-between">
                                                <label class="text-gray-300 text-xs flex items-center gap-1">
                                                    <i class="fas fa-key text-gray-400 w-3 h-3"></i>
                                                    {$Locales["UI.Admin"]}
                                                </label>
                                                <div class="relative flex items-center">
                                                    <input type="checkbox" bind:checked={editingPermissions[identifier].Admin} id="admin-{identifier}" class="sr-only peer" />
                                                    <label for="admin-{identifier}" class="relative flex items-center cursor-pointer">
                                                        <div class="w-4 h-4 bg-[#1e1e1e] border-2 border-[#333333] rounded peer-checked:bg-blue-400 peer-focus:ring-2 peer-focus:ring-blue-400 transition-all duration-200 peer-checked:border-blue-400"></div>
                                                        <div class="absolute inset-0 w-4 h-4 flex items-center justify-center pointer-events-none">
                                                            {#if editingPermissions[identifier].Admin}
                                                                <svg class="w-2.5 h-2.5 text-white" fill="currentColor" viewBox="0 0 20 20">
                                                                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
                                                                </svg>
                                                            {/if}
                                                        </div>
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="pt-1 border-t border-[#333333] flex justify-end">
                                            <button 
                                                onclick={() => savePermissions(identifier)} 
                                                class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded text-xs font-medium transition-colors"
                                            >
                                                {$Locales["UI.Save"]}
                                            </button>
                                        </div>
                                    </div>
                                {/if}
                            </div>
                        {/each}
                    {/if}
                </div>
            </div>
            <!-- Right Side: Sales Data and Administrate -->
            <div class="flex-1 flex flex-col space-y-6">
                <!-- Sales Data Section -->
                {#if $House.SalesData}
                    <div class="bg-[#1a1a1a] rounded-lg border border-[#333333] p-4 flex flex-col">
                        <h2 class="text-white font-semibold mb-4 text-lg flex items-center">
                            <i class="fas fa-chart-line text-green-400 mr-2"></i>
                            {$Locales["UI.SalesData"]}
                        </h2>
                        <div class="space-y-3 text-sm">
                            <div class="bg-[#1e1e1e] rounded-md border border-[#333333] p-3">
                                <div class="flex items-center justify-between">
                                    <span class="text-gray-400 flex items-center gap-1">
                                        <i class="fas fa-tag w-4 h-4"></i>
                                        {$Locales["UI.Price"]}
                                    </span>
                                    <div class="flex items-center gap-2">
                                        <span class="text-white font-semibold">${$House.SalesData.Price}</span>
                                        {#if $House.State == 0}
                                            <span class="bg-blue-400 text-white px-2 py-1 rounded text-xs font-medium">For Sale</span>
                                        {/if}
                                    </div>
                                </div>
                            </div>
                            <div class="bg-[#1e1e1e] rounded-md border border-[#333333] p-3">
                                <div class="flex items-center justify-between">
                                    <span class="text-gray-400 flex items-center gap-1">
                                        <i class="fas fa-briefcase w-4 h-4"></i>
                                            {$Locales["UI.RealEstateJob"]}
                                    </span>
                                    <span class="text-white">{$House.SalesData.SalesmanJobLabel}</span>
                                </div>
                            </div>
                            <div class="bg-[#1e1e1e] rounded-md border border-[#333333] p-3">
                                <div class="flex items-center justify-between">
                                    <span class="text-gray-400 flex items-center gap-1">
                                        <i class="fas fa-user-tie w-4 h-4"></i>
                                        {$Locales["UI.Agent"]}
                                    </span>
                                    <span class="text-white">{$House.SalesData.Salesman}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                {/if}
                <!-- Administrate Section -->
                <div class="flex-1 bg-[#1a1a1a] rounded-lg border border-[#333333] p-4 flex flex-col">
                    <h2 class="text-white font-semibold mb-4 text-lg flex items-center">
                        <i class="fas fa-cog text-purple-400 mr-2"></i>
                        {$Locales["UI.Administrate"]}
                    </h2>
                    <div class="space-y-3">
                        <button onclick={placeWardrobe} class="w-full bg-[#1e1e1e] border border-[#333333] rounded-md p-3 text-left hover:bg-[#2a2a2a] transition-colors text-sm text-white flex items-center gap-3">
                            <i class="fas fa-tshirt text-purple-400 w-5 h-5"></i>
                            {$Locales["UI.PlaceWardrobe"]}
                        </button>
                        <button onclick={placeStash} class="w-full bg-[#1e1e1e] border border-[#333333] rounded-md p-3 text-left hover:bg-[#2a2a2a] transition-colors text-sm text-white flex items-center gap-3">
                            <i class="fas fa-box text-purple-400 w-5 h-5"></i>
                            {$Locales["UI.PlaceStash"]}
                        </button>
                        <button onclick={setStashPin} class="w-full bg-[#1e1e1e] border border-[#333333] rounded-md p-3 text-left hover:bg-[#2a2a2a] transition-colors text-sm text-white flex items-center gap-3">
                            <i class="fas fa-lock text-purple-400 w-5 h-5"></i>
                            {$House.HasStashPin ? $Locales["UI.ChangeStashPin"] : $Locales["UI.SetStashPin"]}
                        </button>
                        <button
                            disabled={false}
                            onclick={startDecorating}
                            class="w-full bg-[#1e1e1e] border border-[#333333] rounded-md p-3 text-left hover:bg-[#2a2a2a] transition-colors text-sm text-white flex items-center gap-3 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            <i class="fas fa-couch text-purple-400 w-5 h-5"></i>
                            {$Locales["UI.Decorate"]}
                        </button>
                    </div>
                </div>
            </div>
        </main>
    </div>
</div>

{#if showSelectPlayer}
    <SelectPlayer on:submit={GiveKey} on:close={CloseModal} />
{/if}

{#if showStashPinInput}
    <Input
        on:confirm={handleStashPinConfirm}
        title={$House.HasStashPin ? $Locales["UI.ChangeStashPin"] : $Locales["UI.SetStashPin"]}
        message={$House.HasStashPin ? $Locales["UI.ChangeStashPinConfirm"] : $Locales["UI.SetStashPinConfirm"]}
        placeholder={$Locales["UI.EnterStashPin"]}
        inputType="text"
        maxlength={4}
        pattern={'\\d{4}'}
    />
{/if}

<style>
    .hide-scrollbar::-webkit-scrollbar {
        display: none;
    }
   
    .hide-scrollbar {
        -ms-overflow-style: none;  /* IE and Edge */
        scrollbar-width: none;  /* Firefox */
    }
    * {
        user-select: none;
        -webkit-user-select: none;
        -moz-user-select: none;
        -ms-user-select: none;
    }
</style>

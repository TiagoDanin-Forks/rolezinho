defmodule Storybook.Welcome do
  use PhoenixStorybook.Story, :page

  def doc, do: "The Rolezinho design system."

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl space-y-6 text-sm leading-relaxed">
      <p>
        This catalog holds the components under <code class="rounded bg-base-200 px-1 py-0.5">lib/rolezinho_web/components/ui/</code>,
        one module per component. Every component here is styled from the design tokens —
        no loose color or radius values.
      </p>

      <div>
        <h2 class="text-base font-extrabold">Where the truth lives</h2>
        <ul class="mt-2 list-disc space-y-1 pl-5">
          <li>
            <strong>Tokens</strong>
            — the frontmatter of <code>DESIGN.md</code>
            and the <code>@theme</code>
            block of <code>assets/css/app.css</code>. The two are a coupled
            pair: changing one requires changing the other in the same commit.
          </li>
          <li><strong>Product decisions</strong> — <code>PRODUCT.md</code>.</li>
          <li><strong>Access levels</strong> — <code>SECURITY.md</code>.</li>
        </ul>
      </div>

      <div>
        <h2 class="text-base font-extrabold">Two colors do the work</h2>
        <p class="mt-2">
          <strong>Ink</strong> (<code>accent</code>) is the primary action: one per screen, at the
          bottom, within thumb reach. <strong>Orange</strong> (<code>primary</code>) marks attention
          and active state — the paid check, a filling list, the selected option. Everything else is
          the warm neutral ramp.
        </p>
      </div>

      <div>
        <h2 class="text-base font-extrabold">Adding a component</h2>
        <p class="mt-2">
          A new module under <code>components/ui/</code>
          needs three things in the same commit: the
          import in <code>rolezinho_web.ex</code>, a <code>.story.exs</code>
          here, and an entry in <code>storybook/ui/_ui.index.exs</code>. A component with no story is invisible to the
          next person.
        </p>
      </div>
    </div>
    """
  end
end
